-------------------------------------------------------------------------------
-- File       : Kcu1500TimingRx.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- This file is part of 'Camera link gateway'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'Camera link gateway', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

-- surf
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

-- timing-core
use work.TimingPkg.all;

-- l2si-core
use work.L2SiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Kcu1500TimingRx is
   generic (
      TPD_G                          : time    := 1 ns;
      SIMULATION_G                   : boolean := false;
      AXIL_CLK_FREQ_G                : real    := 156.25E+6;  -- units of Hz
      DMA_AXIS_CONFIG_G              : AxiStreamConfigType;
      AXI_BASE_ADDR_G                : slv(31 downto 0);
      NUM_DETECTORS_G                : integer range 1 to 4);
   port (
      -- Reference Clock and Reset
      userClk25           : in  sl;
      userRst25           : in  sl;
      -- Trigger Interface
      triggerClk          : in  sl;
      triggerRst          : in  sl;
      triggerData         : out ExperimentEventDataArray(NUM_DETECTORS_G-1 downto 0);
      -- L1 trigger feedback (optional)
      l1Clk               : in  sl                                                    := '0';
      l1Rst               : in  sl                                                    := '0';
      l1Feedbacks         : in  ExperimentL1FeedbackArray(NUM_DETECTORS_G-1 downto 0) := (others => EXPERIMENT_L1_FEEDBACK_INIT_C);
      l1Acks              : out slv(NUM_DETECTORS_G-1 downto 0);
      -- Event streams
      eventClk            : in  sl;
      eventRst            : in  sl;
      eventTimingMessages : out TimingMessageArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisMasters    : out AxiStreamMasterArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisSlaves     : in  AxiStreamSlaveArray(NUM_DETECTORS_G-1 downto 0);
      eventAxisCtrl       : in  AxiStreamCtrlArray(NUM_DETECTORS_G-1 downto 0);
      -- AXI-Lite Interface
      axilClk             : in  sl;
      axilRst             : in  sl;
      axilReadMaster      : in  AxiLiteReadMasterType;
      axilReadSlave       : out AxiLiteReadSlaveType;
      axilWriteMaster     : in  AxiLiteWriteMasterType;
      axilWriteSlave      : out AxiLiteWriteSlaveType;
      -- GT Serial Ports
      timingRxP           : in  slv(1 downto 0);
      timingRxN           : in  slv(1 downto 0);
      timingTxP           : out slv(1 downto 0);
      timingTxN           : out slv(1 downto 0));
end Kcu1500TimingRx;

architecture mapping of Kcu1500TimingRx is

   constant NUM_AXIL_MASTERS_C : positive := 6;

   constant RX_PHY0_INDEX_C : natural := 0;
   constant RX_PHY1_INDEX_C : natural := 1;
   constant MON_INDEX_C     : natural := 2;
   constant TRIG_INDEX_C    : natural := 3;
   constant TIMING_INDEX_C  : natural := 4;
   constant EHC_INDEX_C     : natural := 5;

   constant AXIL_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := (
      RX_PHY0_INDEX_C => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0000_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      RX_PHY1_INDEX_C => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0001_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      MON_INDEX_C     => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0002_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      TRIG_INDEX_C    => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0003_0000"),
         addrBits     => 16,
         connectivity => x"FFFF"),
      TIMING_INDEX_C  => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0008_0000"),
         addrBits     => 18,
         connectivity => x"FFFF"),
      EHC_INDEX_C     => (
         baseAddr     => (AXI_BASE_ADDR_G+x"0009_0000"),
         addrBits     => 12,
         connectivity => x"FFFF"));

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal initReadMaster  : AxiLiteReadMasterType;
   signal initReadSlave   : AxiLiteReadSlaveType;
   signal initWriteMaster : AxiLiteWriteMasterType;
   signal initWriteSlave  : AxiLiteWriteSlaveType;

   signal mmcmRst      : sl;
   signal refClk       : slv(1 downto 0);
   signal refClkDiv2   : slv(1 downto 0);
   signal refRst       : slv(1 downto 0);
   signal refRstDiv2   : slv(1 downto 0);
   signal mmcmLocked   : slv(1 downto 0);
   signal timingClkSel : sl;
   signal useMiniTpg   : sl;
   signal loopback     : slv(2 downto 0);

   signal rxUserRst   : sl;
   signal gtRxOutClk  : slv(1 downto 0);
   signal gtRxClk     : slv(1 downto 0);
   signal timingRxClk : sl;
   signal timingRxRst : sl;
   signal gtRxData    : Slv16Array(1 downto 0);
   signal rxData      : slv(15 downto 0);
   signal gtRxDataK   : Slv2Array(1 downto 0);
   signal rxDataK     : slv(1 downto 0);
   signal gtRxDispErr : Slv2Array(1 downto 0);
   signal rxDispErr   : slv(1 downto 0);
   signal gtRxDecErr  : Slv2Array(1 downto 0);
   signal rxDecErr    : slv(1 downto 0);
   signal gtRxStatus  : TimingPhyStatusArray(1 downto 0);
   signal rxStatus    : TimingPhyStatusType;
   signal rxCtrl      : TimingPhyControlType;
   signal rxControl   : TimingPhyControlType;

   signal txUserRst   : sl;
   signal gtTxOutClk  : slv(1 downto 0);
   signal timingTxClk : sl;
   signal timingTxRst : sl;
   signal txData      : slv(15 downto 0);
   signal txDataK     : slv(1 downto 0);
--   signal txStatus   : TimingPhyStatusType := TIMING_PHY_STATUS_FORCE_C;
   signal gtTxStatus  : TimingPhyStatusArray(1 downto 0);

   signal tpgMiniTimingPhy : TimingPhyType;
   signal appTimingBus     : TimingBusType;
   signal appTimingMode    : sl;

   -----------------------------------------------
   -- Event Header Cache signals
   -----------------------------------------------
   signal ehcTimingTxPhy : TimingPhyType;


begin

   timingTxRst <= txUserRst;
   timingRxRst <= rxUserRst;

   -------------------------   
   -- Reference LCLS-I Clock
   -------------------------   
   U_238MHz : entity work.ClockManagerUltraScale
      generic map(
         TPD_G              => TPD_G,
         SIMULATION_G       => SIMULATION_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 1,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => 40.0,    -- 25 MHz
         DIVCLK_DIVIDE_G    => 1,       -- 25 MHz = 25MHz/1
         CLKFBOUT_MULT_F_G  => 29.750,  -- 743.75 MHz = 25 MHz x 29.75
         CLKOUT0_DIVIDE_F_G => 3.125)   -- 238 MHz = 743.75 MHz/3.125
      port map(
         -- Clock Input
         clkIn     => userClk25,
         rstIn     => mmcmRst,
         -- Clock Outputs
         clkOut(0) => refClk(0),
         -- Reset Outputs
         rstOut(0) => refRst(0),
         -- Locked Status
         locked    => mmcmLocked(0));

   --------------------------   
   -- Reference LCLS-II Clock
   --------------------------           
   U_371MHz : entity work.ClockManagerUltraScale
      generic map(
         TPD_G              => TPD_G,
         SIMULATION_G       => SIMULATION_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 1,
         -- MMCM attributes
         BANDWIDTH_G        => "HIGH",
         CLKIN_PERIOD_G     => 40.0,    -- 25 MHz
         DIVCLK_DIVIDE_G    => 1,       -- 25 MHz = 25MHz/1
         CLKFBOUT_MULT_F_G  => 52.000,  -- 1.3 GHz = 25 MHz x 52
         CLKOUT0_DIVIDE_F_G => 3.500)   -- 371.429 MHz = 1.3 GHz/3.5
      port map(
         -- Clock Input
         clkIn     => userClk25,
         rstIn     => mmcmRst,
         -- Clock Outputs
         clkOut(0) => refClk(1),
         -- Reset Outputs
         rstOut(0) => refRst(1),
         -- Locked Status
         locked    => mmcmLocked(1));

   -------------------------------------------------------
   -- Power Up Initialization of the KCU1500 Timing RX PHY
   -------------------------------------------------------
   U_TimingPhyInit : entity work.TimingPhyInit
      generic map (
         TPD_G              => TPD_G,
         SIMULATION_G       => SIMULATION_G,
         TIMING_BASE_ADDR_G => AXIL_CONFIG_C(TIMING_INDEX_C).baseAddr,
         AXIL_CLK_FREQ_G    => AXIL_CLK_FREQ_G)
      port map (
         mmcmLocked       => mmcmLocked,
         -- AXI-Lite Register Interface (sysClk domain)
         axilClk          => axilClk,
         axilRst          => axilRst,
         mAxilReadMaster  => initReadMaster,
         mAxilReadSlave   => initReadSlave,
         mAxilWriteMaster => initWriteMaster,
         mAxilWriteSlave  => initWriteSlave);

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------
   U_XBAR : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 2,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteMasters(1) => initWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiWriteSlaves(1)  => initWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadMasters(1)  => initReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         sAxiReadSlaves(1)   => initReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   -------------
   -- GTH Module
   -------------
   GEN_VEC : for i in 1 downto 0 generate

      U_refClkDiv2 : BUFGCE_DIV
         generic map (
            BUFGCE_DIVIDE => 2)
         port map (
            I   => refClk(i),
            CE  => '1',
            CLR => '0',
            O   => refClkDiv2(i));

      U_refRstDiv2 : entity work.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => refClkDiv2(i),
            asyncRst => refRst(i),
            syncRst  => refRstDiv2(i));

      U_RXCLK : BUFGMUX
         generic map (
            CLK_SEL_TYPE => "ASYNC")    -- ASYNC, SYNC
         port map (
            O  => gtRxClk(i),           -- 1-bit output: Clock output
            I0 => gtRxOutClk(i),        -- 1-bit input: Clock input (S=0)
            I1 => refClkDiv2(i),        -- 1-bit input: Clock input (S=1)
            S  => useMiniTpg);          -- 1-bit input: Clock select      

      REAL_PCIE : if (not SIMULATION_G) generate
         U_GTH : entity work.TimingGtCoreWrapper
            generic map (
               TPD_G            => TPD_G,
               EXTREF_G         => false,
               AXIL_BASE_ADDR_G => AXIL_CONFIG_C(RX_PHY0_INDEX_C+i).baseAddr,
               ADDR_BITS_G      => 12,
               GTH_DRP_OFFSET_G => x"00001000")
            port map (
               -- AXI-Lite Port
               axilClk         => axilClk,
               axilRst         => axilRst,
               axilReadMaster  => axilReadMasters(RX_PHY0_INDEX_C+i),
               axilReadSlave   => axilReadSlaves(RX_PHY0_INDEX_C+i),
               axilWriteMaster => axilWriteMasters(RX_PHY0_INDEX_C+i),
               axilWriteSlave  => axilWriteSlaves(RX_PHY0_INDEX_C+i),
               stableClk       => axilClk,
               stableRst       => axilRst,
               -- GTH FPGA IO
               gtRefClk        => refClk(i),
               gtRefClkDiv2    => refClkDiv2(i),
               gtRxP           => timingRxP(i),
               gtRxN           => timingRxN(i),
               gtTxP           => timingTxP(i),
               gtTxN           => timingTxN(i),
               -- Rx ports
               rxControl       => rxControl,
               rxStatus        => gtRxStatus(i),
               rxUsrClkActive  => mmcmLocked(i),
               rxUsrClk        => timingRxClk,
               rxData          => gtRxData(i),
               rxDataK         => gtRxDataK(i),
               rxDispErr       => gtRxDispErr(i),
               rxDecErr        => gtRxDecErr(i),
               rxOutClk        => gtRxOutClk(i),
               -- Tx Ports
               txControl       => ehcTimingTxPhy.control,
               txStatus        => gtTxStatus(i),
               txUsrClk        => timingTxClk,
               txUsrClkActive  => mmcmLocked(i),
               txData          => ehcTimingTxPhy.data,
               txDataK         => ehcTimingTxPhy.dataK,
               txOutClk        => gtTxOutClk(i),
               -- Misc.
               loopback        => loopback);
      end generate;


      SIM_PCIE : if (SIMULATION_G) generate

         axilReadSlaves(RX_PHY0_INDEX_C+i)  <= AXI_LITE_READ_SLAVE_EMPTY_OK_C;
         axilWriteSlaves(RX_PHY0_INDEX_C+i) <= AXI_LITE_WRITE_SLAVE_EMPTY_OK_C;

         gtRxOutClk(i) <= refClkDiv2(i);
         gtTxOutClk(i) <= refClkDiv2(i);

         gtTxStatus(i)  <= TIMING_PHY_STATUS_FORCE_C;
         gtRxStatus(i)  <= TIMING_PHY_STATUS_FORCE_C;
         gtRxData(i)    <= ehcTimingTxPhy.data;
         gtRxDataK(i)   <= ehcTimingTxPhy.dataK;
         gtRxDispErr(i) <= "00";
         gtRxDecErr(i)  <= "00";

      end generate;
   end generate GEN_VEC;

   process(timingRxClk)
   begin
      -- Register to help meet timing
      if rising_edge(timingRxClk) then
         if (useMiniTpg = '1') then
--            txStatus  <= TIMING_PHY_STATUS_FORCE_C after TPD_G;
            rxStatus  <= TIMING_PHY_STATUS_FORCE_C after TPD_G;
            rxData    <= tpgMiniTimingPhy.data     after TPD_G;
            rxDataK   <= tpgMiniTimingPhy.dataK    after TPD_G;
            rxDispErr <= "00"                      after TPD_G;
            rxDecErr  <= "00"                      after TPD_G;
         elsif (timingClkSel = '1') then
--            txStatus  <= gtTxStatus(1)  after TPD_G;
            rxStatus  <= gtRxStatus(1)  after TPD_G;
            rxData    <= gtRxData(1)    after TPD_G;
            rxDataK   <= gtRxDataK(1)   after TPD_G;
            rxDispErr <= gtRxDispErr(1) after TPD_G;
            rxDecErr  <= gtRxDecErr(1)  after TPD_G;
         else
--            txStatus  <= gtTxStatus(0)  after TPD_G;
            rxStatus  <= gtRxStatus(0)  after TPD_G;
            rxData    <= gtRxData(0)    after TPD_G;
            rxDataK   <= gtRxDataK(0)   after TPD_G;
            rxDispErr <= gtRxDispErr(0) after TPD_G;
            rxDecErr  <= gtRxDecErr(0)  after TPD_G;
         end if;
      end if;
   end process;

   U_RXCLK : BUFGMUX
      generic map (
         CLK_SEL_TYPE => "ASYNC")       -- ASYNC, SYNC
      port map (
         O  => timingRxClk,             -- 1-bit output: Clock output
         I0 => gtRxClk(0),              -- 1-bit input: Clock input (S=0)
         I1 => gtRxClk(1),              -- 1-bit input: Clock input (S=1)
         S  => timingClkSel);           -- 1-bit input: Clock select         

   U_TXCLK : BUFGMUX
      generic map (
         CLK_SEL_TYPE => "ASYNC")       -- ASYNC, SYNC
      port map (
         O  => timingTxClk,             -- 1-bit output: Clock output
         I0 => refClkDiv2(0),           -- 1-bit input: Clock input (S=0)
         I1 => refClkDiv2(1),           -- 1-bit input: Clock input (S=1)
         S  => timingClkSel);           -- 1-bit input: Clock select         

   -----------------------
   -- Insert user RX reset
   -----------------------
   rxControl.reset       <= rxCtrl.reset or rxUserRst;
   rxControl.inhibit     <= rxCtrl.inhibit;
   rxControl.polarity    <= rxCtrl.polarity;
   rxControl.bufferByRst <= rxCtrl.bufferByRst;
   rxControl.pllReset    <= rxCtrl.pllReset or rxUserRst;

   --------------
   -- Timing Core
   --------------
   U_TimingCore : entity work.TimingCore
      generic map (
         TPD_G             => TPD_G,
         DEFAULT_CLK_SEL_G => '0',      -- '0': default LCLS-I, '1': default LCLS-II
         AXIL_RINGB_G      => false,
         ASYNC_G           => false,
         AXIL_BASE_ADDR_G  => AXIL_CONFIG_C(TIMING_INDEX_C).baseAddr)
      port map (
         -- GT Interface
         gtTxUsrClk       => timingTxClk,
         gtTxUsrRst       => timingTxRst,
         gtRxRecClk       => timingRxClk,
         gtRxData         => rxData,
         gtRxDataK        => rxDataK,
         gtRxDispErr      => rxDispErr,
         gtRxDecErr       => rxDecErr,
         gtRxControl      => rxCtrl,
         gtRxStatus       => rxStatus,
         tpgMiniTimingPhy => tpgMiniTimingPhy,
         timingClkSel     => timingClkSel,
         -- Decoded timing message interface
         appTimingClk     => timingRxClk,
         appTimingRst     => timingRxRst,
         appTimingMode    => appTimingMode,
         appTimingBus     => appTimingBus,
         -- AXI Lite interface
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMasters(TIMING_INDEX_C),
         axilReadSlave    => axilReadSlaves(TIMING_INDEX_C),
         axilWriteMaster  => axilWriteMasters(TIMING_INDEX_C),
         axilWriteSlave   => axilWriteSlaves(TIMING_INDEX_C));

   ---------------------
   -- Timing PHY Monitor
   -- This is mostly unused now. Trigger monitoring is done in the TriggerEventManager
   -- Still need the useMiniTpg register
   ---------------------
   U_Monitor : entity work.TimingPhyMonitor
      generic map (
         TPD_G           => TPD_G,
         SIMULATION_G    => SIMULATION_G,
         AXIL_CLK_FREQ_G => AXIL_CLK_FREQ_G)
      port map (
         rxUserRst       => rxUserRst,
         txUserRst       => txUserRst,
         useMiniTpg      => useMiniTpg,
         mmcmRst         => mmcmRst,
         loopback        => loopback,
         remTrig         => (others => '0'),  --remTrig,
         remTrigDrop     => (others => '0'),  --remTrigDrop,
         locTrig         => (others => '0'),  --locTrig,
         locTrigDrop     => (others => '0'),  --locTrigDrop,
         mmcmLocked      => mmcmLocked,
         refClk          => refClk,
         refRst          => refRst,
         txClk           => timingTxClk,
         txRst           => timingTxRst,
         rxClk           => timingRxClk,
         rxRst           => timingRxRst,
         -- AXI Lite interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(MON_INDEX_C),
         axilReadSlave   => axilReadSlaves(MON_INDEX_C),
         axilWriteMaster => axilWriteMasters(MON_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(MON_INDEX_C));


   ---------------------------------------------------------------
   -- Decode events and buffer them for the application
   ---------------------------------------------------------------
   U_TriggerEventManager_1 : entity work.TriggerEventManager
      generic map (
         TPD_G                          => TPD_G,
         NUM_DETECTORS_G                => NUM_DETECTORS_G,                   -- ???
         AXIL_BASE_ADDR_G               => AXIL_CONFIG_C(EHC_INDEX_C).baseAddr,
         L1_CLK_IS_TIMING_TX_CLK_G      => false,
         TRIGGER_CLK_IS_TIMING_RX_CLK_G => false,
         EVENT_CLK_IS_TIMING_RX_CLK_G   => false)
      port map (
         timingRxClk         => timingRxClk,                    -- [in]
         timingRxRst         => timingRxRst,                    -- [in]
         timingBus           => appTimingBus,                   -- [in]
         timingTxClk         => timingTxClk,                    -- [in]
         timingTxRst         => timingTxRst,                    -- [in]
         timingTxPhy         => ehcTimingTxPhy,                 -- [out]
         triggerClk          => triggerClk,                     -- [in]
         triggerRst          => triggerRst,                     -- [in]
         triggerData         => triggerData,                    -- [out]
         l1Clk               => l1Clk,                          -- [in]
         l1Rst               => l1Rst,                          -- [in]  
         l1Feedbacks         => l1Feedbacks,                    -- [in]  
         l1Acks              => l1Acks,                         -- [out] 
         eventClk            => eventClk,                       -- [in]
         eventRst            => eventRst,                       -- [in]
         eventTimingMessages => eventTimingMessages,            -- [out]
         eventAxisMasters    => eventAxisMasters,               -- [out]
         eventAxisSlaves     => eventAxisSlaves,                -- [in]
         eventAxisCtrl       => eventAxisCtrl,                  -- [in]
         axilClk             => axilClk,                        -- [in]
         axilRst             => axilRst,                        -- [in]
         axilReadMaster      => axilReadMasters(EHC_INDEX_C),   -- [in]
         axilReadSlave       => axilReadSlaves(EHC_INDEX_C),    -- [out]
         axilWriteMaster     => axilWriteMasters(EHC_INDEX_C),  -- [in]
         axilWriteSlave      => axilWriteSlaves(EHC_INDEX_C));  -- [out]

end mapping;