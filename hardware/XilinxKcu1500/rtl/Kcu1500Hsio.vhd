-------------------------------------------------------------------------------
-- File       : Kcu1500Hsio.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Kcu1500Hsio File
-------------------------------------------------------------------------------
-- Fiber Mapping to Kcu1500Hsio:
--    QSFP[0][0] = PGP.Lane[0].VC[3:0]
--    QSFP[0][1] = PGP.Lane[1].VC[3:0]
--    QSFP[0][2] = PGP.Lane[2].VC[3:0]
--    QSFP[0][3] = PGP.Lane[3].VC[3:0]
--    QSFP[1][0] = LCLS-I  Timing Receiver
--    QSFP[1][1] = LCLS-II Timing Receiver
--    QSFP[1][2] = Unused QSFP Link
--    QSFP[1][3] = Unused QSFP Link
-------------------------------------------------------------------------------
-- This file is part of LCLS2 PGP Firmware Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of LCLS2 PGP Firmware Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library l2si_core;
use l2si_core.L2SiPkg.all;

-- Library that this module belongs to
library lcls2_pgp_fw_lib;

entity Kcu1500Hsio is
   generic (
      TPD_G                          : time                        := 1 ns;
      ROGUE_SIM_EN_G                 : boolean                     := false;
      ROGUE_SIM_PORT_NUM_G           : natural range 1024 to 49151 := 7000;
      DMA_AXIS_CONFIG_G              : AxiStreamConfigType;
      PGP_TYPE_G                     : string                      := "PGP2b";  -- PGP2b@3.125Gb/s, PGP3@10.3125Gb/s
      AXIL_CLK_FREQ_G                : real                        := 156.25E+6;  -- units of Hz
      AXI_BASE_ADDR_G                : slv(31 downto 0)            := x"0080_0000";
      NUM_PGP_LANES_G                : integer range 1 to 4        := 4;
      EN_LCLS_I_TIMING_G             : boolean                     := true;
      EN_LCLS_II_TIMING_G            : boolean                     := true;
      L1_CLK_IS_TIMING_TX_CLK_G      : boolean                     := false;
      TRIGGER_CLK_IS_TIMING_RX_CLK_G : boolean                     := false;
      EVENT_CLK_IS_TIMING_RX_CLK_G   : boolean                     := false);
   port (
      ------------------------      
      --  Top Level Interfaces
      ------------------------    
      -- Reference Clock and Reset
      userClk25           : in  sl;
      userRst25           : in  sl;
      -- AXI-Lite Interface
      axilClk             : in  sl;
      axilRst             : in  sl;
      axilReadMaster      : in  AxiLiteReadMasterType;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType;
      axilWriteSlave      : out AxiLiteWriteSlaveType;
      -- PGP Streams (axilClk domain)
      pgpIbMasters        : in  AxiStreamMasterArray(NUM_PGP_LANES_G-1 downto 0);
      pgpIbSlaves         : out AxiStreamSlaveArray(NUM_PGP_LANES_G-1 downto 0);
      pgpObMasters        : out AxiStreamQuadMasterArray(NUM_PGP_LANES_G-1 downto 0);
      pgpObSlaves         : in  AxiStreamQuadSlaveArray(NUM_PGP_LANES_G-1 downto 0);
      -- Trigger Interface
      triggerClk          : in  sl;
      triggerRst          : in  sl;
      triggerData         : out TriggerEventDataArray(NUM_PGP_LANES_G-1 downto 0);
      -- L1 trigger feedback (optional)
      l1Clk               : in  sl                                                 := '0';
      l1Rst               : in  sl                                                 := '0';
      l1Feedbacks         : in  TriggerL1FeedbackArray(NUM_PGP_LANES_G-1 downto 0) := (others => TRIGGER_L1_FEEDBACK_INIT_C);
      l1Acks              : out slv(NUM_PGP_LANES_G-1 downto 0);
      -- Event streams
      eventClk            : in  sl;
      eventRst            : in  sl;
      eventTimingMessages : out TimingMessageArray(NUM_PGP_LANES_G-1 downto 0);
      eventAxisMasters    : out AxiStreamMasterArray(NUM_PGP_LANES_G-1 downto 0);
      eventAxisSlaves     : in  AxiStreamSlaveArray(NUM_PGP_LANES_G-1 downto 0);
      eventAxisCtrl       : in  AxiStreamCtrlArray(NUM_PGP_LANES_G-1 downto 0);
      clearReadout        : out slv(NUM_PGP_LANES_G-1 downto 0);

      ---------------------
      --  Kcu1500Hsio Ports
      ---------------------    
      -- QSFP[0] Ports
      qsfp0RefClkP : in    slv(1 downto 0) := (others => '0');
      qsfp0RefClkN : in    slv(1 downto 0) := (others => '0');
      qsfp0RxP     : in    slv(3 downto 0) := (others => '0');
      qsfp0RxN     : in    slv(3 downto 0) := (others => '0');
      qsfp0TxP     : out   slv(3 downto 0) := (others => '0');
      qsfp0TxN     : out   slv(3 downto 0) := (others => '0');
      -- QSFP[1] Ports
      qsfp1RefClkP : in    slv(1 downto 0) := (others => '0');
      qsfp1RefClkN : in    slv(1 downto 0) := (others => '0');
      qsfp1RxP     : in    slv(3 downto 0) := (others => '0');
      qsfp1RxN     : in    slv(3 downto 0) := (others => '0');
      qsfp1TxP     : out   slv(3 downto 0) := (others => '0');
      qsfp1TxN     : out   slv(3 downto 0) := (others => '0');
      -- QSFP I2C
      scl          : inout sl;
      sda          : inout sl);

end Kcu1500Hsio;

architecture mapping of Kcu1500Hsio is

   constant NUM_AXIL_MASTERS_C : positive := 5;

   constant PGP_INDEX_C    : natural := 0;
   constant TIMING_INDEX_C : natural := 4;

   -- 22 Bits available
   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := (
      PGP_INDEX_C+0   => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0000_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      PGP_INDEX_C+1   => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0001_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      PGP_INDEX_C+2   => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0002_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      PGP_INDEX_C+3   => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0003_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      TIMING_INDEX_C  => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0010_0000"),
         addrBits     => 20,
         connectivity => x"FFFF"));

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0) := (others => AXI_LITE_WRITE_SLAVE_EMPTY_DECERR_C);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0)  := (others => AXI_LITE_READ_SLAVE_EMPTY_DECERR_C);

   signal qpllLock   : Slv2Array(3 downto 0);
   signal qpllClk    : Slv2Array(3 downto 0);
   signal qpllRefclk : Slv2Array(3 downto 0);
   signal qpllRst    : Slv2Array(3 downto 0);

   signal refClk    : slv(3 downto 0);
   signal refClkDiv : slv(3 downto 0);

   signal iTriggerData       : TriggerEventDataArray(NUM_PGP_LANES_G-1 downto 0);
   signal remoteTriggersComb : slv(NUM_PGP_LANES_G-1 downto 0);
   signal remoteTriggers     : slv(NUM_PGP_LANES_G-1 downto 0);
   signal triggerCodes       : slv8Array(NUM_PGP_LANES_G-1 downto 0);

   attribute dont_touch              : string;
   attribute dont_touch of refClk    : signal is "TRUE";
   attribute dont_touch of refClkDiv : signal is "TRUE";

begin

   assert ((PGP_TYPE_G = "PGP2b") or (PGP_TYPE_G = "PGP3"))
      report "PGP_TYPE_G must be either PGP2b or PGP3" severity failure;

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   ------------------------
   -- GT Clocking
   ------------------------
   GEN_REFCLK :
   for i in 1 downto 0 generate

      U_QsfpRef0 : IBUFDS_GTE3
         generic map (
            REFCLK_EN_TX_PATH  => '0',
            REFCLK_HROW_CK_SEL => "00",  -- 2'b00: ODIV2 = O
            REFCLK_ICNTL_RX    => "00")
         port map (
            I     => qsfp0RefClkP(i),
            IB    => qsfp0RefClkN(i),
            CEB   => '0',
            ODIV2 => open,
            O     => refClk((2*i)+0));

      U_QsfpRef1 : IBUFDS_GTE3
         generic map (
            REFCLK_EN_TX_PATH  => '0',
            REFCLK_HROW_CK_SEL => "00",  -- 2'b00: ODIV2 = O
            REFCLK_ICNTL_RX    => "00")
         port map (
            I     => qsfp1RefClkP(i),
            IB    => qsfp1RefClkN(i),
            CEB   => '0',
            ODIV2 => open,
            O     => refClk((2*i)+1));

   end generate GEN_REFCLK;

   GEN_PGP3_QPLL : if (PGP_TYPE_G = "PGP3") generate
      U_QPLL : entity surf.Pgp3GthUsQpll
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Stable Clock and Reset
            stableClk  => axilClk,
            stableRst  => axilRst,
            -- QPLL Clocking
            pgpRefClk  => refClk(0),
            qpllLock   => qpllLock,
            qpllClk    => qpllClk,
            qpllRefclk => qpllRefclk,
            qpllRst    => qpllRst);
   end generate;

   --------------
   -- PGP Modules
   --------------
   GEN_LANE :
   for i in NUM_PGP_LANES_G-1 downto 0 generate

      GEN_PGP3 : if (PGP_TYPE_G = "PGP3") generate
         U_Lane : entity lcls2_pgp_fw_lib.Pgp3Lane
            generic map (
               TPD_G                => TPD_G,
               ROGUE_SIM_EN_G       => ROGUE_SIM_EN_G,
               ROGUE_SIM_PORT_NUM_G => (ROGUE_SIM_PORT_NUM_G + i*34),
               DMA_AXIS_CONFIG_G    => DMA_AXIS_CONFIG_G,
               AXIL_CLK_FREQ_G      => AXIL_CLK_FREQ_G,
               AXI_BASE_ADDR_G      => AXIL_CONFIG_C(i).baseAddr)
            port map (
               -- Trigger Interface
               trigger         => remoteTriggers(i),
               triggerCode     => triggerCodes(i),
               -- QPLL Interface
               qpllLock        => qpllLock(i),
               qpllClk         => qpllClk(i),
               qpllRefclk      => qpllRefclk(i),
               qpllRst         => qpllRst(i),
               -- PGP Serial Ports
               pgpRxP          => qsfp0RxP(i),
               pgpRxN          => qsfp0RxN(i),
               pgpTxP          => qsfp0TxP(i),
               pgpTxN          => qsfp0TxN(i),
               -- Streaming Interface (axilClk domain)
               pgpIbMaster     => pgpIbMasters(i),
               pgpIbSlave      => pgpIbSlaves(i),
               pgpObMasters    => pgpObMasters(i),
               pgpObSlaves     => pgpObSlaves(i),
               -- AXI-Lite Interface (axilClk domain)
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMasters(i),
               axilReadSlave   => axilReadSlaves(i),
               axilWriteMaster => axilWriteMasters(i),
               axilWriteSlave  => axilWriteSlaves(i));
      end generate;

      GEN_PGP2b : if (PGP_TYPE_G = "PGP2b") generate
         U_Lane : entity lcls2_pgp_fw_lib.Pgp2bLane
            generic map (
               TPD_G                => TPD_G,
               ROGUE_SIM_EN_G       => ROGUE_SIM_EN_G,
               ROGUE_SIM_PORT_NUM_G => (ROGUE_SIM_PORT_NUM_G + i*34),
               DMA_AXIS_CONFIG_G    => DMA_AXIS_CONFIG_G,
               AXIL_CLK_FREQ_G      => AXIL_CLK_FREQ_G,
               AXI_BASE_ADDR_G      => AXIL_CONFIG_C(i).baseAddr)
            port map (
               -- Trigger Interface
               trigger         => remoteTriggers(i),
               triggerCode     => triggerCodes(i),
               -- PGP Serial Ports
               pgpRxP          => qsfp0RxP(i),
               pgpRxN          => qsfp0RxN(i),
               pgpTxP          => qsfp0TxP(i),
               pgpTxN          => qsfp0TxN(i),
               pgpRefClk       => refClk(0),
               -- Streaming Interface (axilClk domain)
               pgpIbMaster     => pgpIbMasters(i),
               pgpIbSlave      => pgpIbSlaves(i),
               pgpObMasters    => pgpObMasters(i),
               pgpObSlaves     => pgpObSlaves(i),
               -- AXI-Lite Interface (axilClk domain)
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMasters(i),
               axilReadSlave   => axilReadSlaves(i),
               axilWriteMaster => axilWriteMasters(i),
               axilWriteSlave  => axilWriteSlaves(i));
      end generate;

   end generate GEN_LANE;

--   SIM_GUARD_0 : if (not ROGUE_SIM_EN_G) generate
   GEN_DUMMY : if (NUM_PGP_LANES_G < 4) generate
      U_QSFP1 : entity surf.Gthe3ChannelDummy
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 4-NUM_PGP_LANES_G)
         port map (
            refClk => axilClk,
            gtRxP  => qsfp0RxP(3 downto NUM_PGP_LANES_G),
            gtRxN  => qsfp0RxN(3 downto NUM_PGP_LANES_G),
            gtTxP  => qsfp0TxP(3 downto NUM_PGP_LANES_G),
            gtTxN  => qsfp0TxN(3 downto NUM_PGP_LANES_G));
   end generate GEN_DUMMY;
--   end generate SIM_GUARD_0;
   ------------------
   -- Timing Receiver
   ------------------
   U_TimingRx : entity lcls2_pgp_fw_lib.Kcu1500TimingRx
      generic map (
         TPD_G               => TPD_G,
         SIMULATION_G        => ROGUE_SIM_EN_G,
         DMA_AXIS_CONFIG_G   => DMA_AXIS_CONFIG_G,
         AXIL_CLK_FREQ_G     => AXIL_CLK_FREQ_G,
         AXI_BASE_ADDR_G     => AXIL_CONFIG_C(TIMING_INDEX_C).baseAddr,
         NUM_DETECTORS_G     => NUM_PGP_LANES_G,
         EN_LCLS_I_TIMING_G  => EN_LCLS_I_TIMING_G,
         EN_LCLS_II_TIMING_G => EN_LCLS_II_TIMING_G)
      port map (
         -- Reference Clock and Reset
         userClk25           => userClk25,
         userRst25           => userRst25,
         -- Trigger / event interfaces
         triggerClk          => triggerClk,           -- [in]
         triggerRst          => triggerRst,           -- [in]
         triggerData         => iTriggerData,         -- [out]
         l1Clk               => l1Clk,                -- [in]
         l1Rst               => l1Rst,                -- [in]  
         l1Feedbacks         => l1Feedbacks,          -- [in]  
         l1Acks              => l1Acks,               -- [out] 
         eventClk            => eventClk,             -- [in]
         eventRst            => eventRst,             -- [in]
         eventTimingMessages => eventTimingMessages,  -- [out]
         eventAxisMasters    => eventAxisMasters,     -- [out]
         eventAxisSlaves     => eventAxisSlaves,      -- [in]
         eventAxisCtrl       => eventAxisCtrl,        -- [in]
         clearReadout        => clearReadout,         -- [out]
         -- AXI-Lite Interface (axilClk domain)
         axilClk             => axilClk,
         axilRst             => axilRst,
         axilReadMaster      => axilReadMasters(TIMING_INDEX_C),
         axilReadSlave       => axilReadSlaves(TIMING_INDEX_C),
         axilWriteMaster     => axilWriteMasters(TIMING_INDEX_C),
         axilWriteSlave      => axilWriteSlaves(TIMING_INDEX_C),
         -- GT Serial Ports
         timingRxP           => qsfp1RxP(1 downto 0),
         timingRxN           => qsfp1RxN(1 downto 0),
         timingTxP           => qsfp1TxP(1 downto 0),
         timingTxN           => qsfp1TxN(1 downto 0),
         scl                 => scl,
         sda                 => sda);


   -- Feed l0 triggers directly to PGP
   TRIGGER_GEN : for i in NUM_PGP_LANES_G-1 downto 0 generate
      remoteTriggersComb(i) <= iTriggerData(i).valid and iTriggerData(i).l0Accept;
      triggerCodes(i)       <= "000" & iTriggerData(i).l0Tag;
   end generate TRIGGER_GEN;
   U_RegisterVector_1 : entity surf.RegisterVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => NUM_PGP_LANES_G)
      port map (
         clk   => triggerClk,           -- [in]
         sig_i => remoteTriggersComb,   -- [in]
         reg_o => remoteTriggers);      -- [out]

   triggerData <= iTriggerData;

   --------------------
   -- Unused QSFP Links
   --------------------
--   SIM_GUARD : if (not ROGUE_SIM_EN_G) generate
   U_QSFP1 : entity surf.Gthe3ChannelDummy
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 2)
      port map (
         refClk => axilClk,
         gtRxP  => qsfp1RxP(3 downto 2),
         gtRxN  => qsfp1RxN(3 downto 2),
         gtTxP  => qsfp1TxP(3 downto 2),
         gtTxN  => qsfp1TxN(3 downto 2));
--   end generate SIM_GUARD;

end mapping;
