-------------------------------------------------------------------------------
-- Title      : Kcu1500 I2C Interface
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Provides an AXI-Lite interface ot the main_i2c bus on the
--              Kcu1500
-------------------------------------------------------------------------------
-- This file is part of LCLS2 PGP Firmware Library. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of LCLS2 PGP Firmware Library, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;


library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;

entity Kcu1500I2c is
   generic (
      TPD_G           : time := 1 ns;
      I2C_SCL_FREQ_G  : real := 100.0E+3;    -- units of Hz
      I2C_MIN_PULSE_G : real := 100.0E-9;    -- units of seconds
      AXI_CLK_FREQ_G  : real := 156.25E+6);  -- units of Hz
   port (
      -- I2C Ports
      scl             : inout sl;
      sda             : inout sl;
      -- AXI-Lite Register Interface
      axilClk         : in    sl;
      axilRst         : in    sl;
      axilReadMaster  : in    AxiLiteReadMasterType;
      axilReadSlave   : out   AxiLiteReadSlaveType;
      axilWriteMaster : in    AxiLiteWriteMasterType;
      axilWriteSlave  : out   AxiLiteWriteSlaveType);
end Kcu1500I2c;

architecture mapping of Kcu1500I2c is

   constant DEVICE_MAP_C : I2cAxiLiteDevArray(0 to 2) := (
      0              => MakeI2cAxiLiteDevType(
         i2cAddress  => "1010000",              -- Configuration PROM
         dataSize    => 8,                      -- in units of bits
         addrSize    => 8,                      -- in units of bits
         endianness  => '0',                    -- Little endian                   
         repeatStart => '0'),                   -- Repeat start    
      1              => MakeI2cAxiLiteDevType(  -- Enhanced interface
         i2cAddress  => "1010001",              -- Diagnostic Monitoring 
         dataSize    => 8,                      -- in units of bits
         addrSize    => 8,                      -- in units of bits
         endianness  => '0',                    -- Little endian   
         repeatStart => '0'),                   -- Repeat Start
      2              => MakeI2cAxiLiteDevType(  -- TCA9548A I2C Switch
         i2cAddress  => "1110100",
         dataSize    => 8,
         addrSize    => 0,
         endianness  => '0',
         repeatStart => '0'));

begin

   U_AxiI2C : entity surf.AxiI2cRegMaster
      generic map (
         TPD_G          => TPD_G,
         AXIL_PROXY_G   => true,
         DEVICE_MAP_G   => DEVICE_MAP_C,
         I2C_SCL_FREQ_G => 400.0E+3,
--         I2C_MIN_PULSE_G => I2C_MIN_PULSE_G,
         AXI_CLK_FREQ_G => 125.0E6)
      port map (
         -- I2C Ports
         scl            => scl,
         sda            => sda,
         -- AXI-Lite Register Interface
         axiReadMaster  => axilReadMaster,
         axiReadSlave   => axilReadSlave,
         axiWriteMaster => axilWriteMaster,
         axiWriteSlave  => axilWriteSlave,
         -- Clocks and Resets
         axiClk         => axilClk,
         axiRst         => axilRst);

end mapping;
