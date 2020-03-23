#-----------------------------------------------------------------------------
# This file is part of the LCLS2 PGP Firmware Library'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the LCLS2 PGP Firmware Library', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import pyrogue as pr

class TimingPhyMonitor(pr.Device):
    def __init__(   self,       
            description = "Timing Debug Monitor Module",
            numLanes     = 4,
            **kwargs):
        super().__init__(description=description, **kwargs)
        
        self.add(pr.RemoteCommand(  
            name         = "MmcmRst",
            offset       = 0x00,
            bitSize      = 1,
            bitOffset    = 0,
            function     = pr.BaseCommand.touchOne,
        ))          
        
        self.add(pr.RemoteVariable( 
            name         = "MmcmLocked",
            offset       = 0x04,
            bitSize      = 2,
            bitOffset    = 0,
            mode         = "RO",
            pollInterval = 1,
            hidden       = False, 
        ))   

        self.add(pr.RemoteVariable( 
            name         = "RefRstStatus",
            offset       = 0x08,
            bitSize      = 2,
            bitOffset    = 0,
            mode         = "RO",
            pollInterval = 1,
            hidden       = False, 
        ))           
        
        self.add(pr.RemoteVariable(
            name        = "Loopback", 
            description = "GT Loopback Mode",
            offset      = 0xC, 
            bitSize     = 3, 
            bitOffset   = 0, 
            mode        = "RW", 
            enum = {
                0: 'No',
                1: 'Near-end PCS',
                2: 'Near-end PMA',
                4: 'Far-end PMA',
                6: 'Far-end PCS',
            },
        ))        

        self.add(pr.RemoteVariable( 
            name         = "UseMiniTpg",
            description  = "Enables usage of the local miniTPG module in the Timing RX module (stand alone testing)",
            offset       = 0x10,
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.Bool,
            mode         = "RW",
        ))      
        
        self.add(pr.RemoteCommand(  
            name         = "RxUserRst",
            offset       = 0x14,
            bitSize      = 1,
            bitOffset    = 0,
            function     = pr.BaseCommand.touchOne,
        ))   
        
        self.add(pr.RemoteCommand(  
            name         = "TxUserRst",
            offset       = 0x18,
            bitSize      = 1,
            bitOffset    = 0,
            function     = pr.BaseCommand.touchOne,
        ))
        
        self.add(pr.RemoteCommand(  
            name         = "TxPhyReset",
            offset       = 0x18,
            bitSize      = 1,
            bitOffset    = 1,
            function     = pr.BaseCommand.touchOne,
        ))
        
        self.add(pr.RemoteCommand(  
            name         = "TxPhyPllReset",
            offset       = 0x18,
            bitSize      = 1,
            bitOffset    = 2,
            function     = pr.BaseCommand.touchOne,
        ))

        
        self.add(pr.RemoteVariable( 
            name         = "TxRstStatus",
            offset       = 0x20,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = "RO",
            pollInterval = 1,
            hidden       = False, 
        )) 

        self.add(pr.RemoteVariable( 
            name         = "RxRstStatus",
            offset       = 0x24,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = "RO",
            pollInterval = 1,
            hidden       = False, 
        )) 
        
        self.addRemoteVariables(   
            name         = "RefClkFreq",
            offset       =  0x30,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = 2,
            stride       = 4,
        )          
        
        self.add(pr.RemoteVariable( 
            name         = "TxClkFreq",
            offset       = 0x38,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
        )) 
        
        self.add(pr.RemoteVariable( 
            name         = "RxClkFreq",
            offset       = 0x3C,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
        ))       
        
        self.addRemoteVariables(   
            name         = "LocalTrigRate",
            offset       =  0x40,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 4,
        ) 

        self.addRemoteVariables(   
            name         = "RemoteTrigRate",
            offset       =  0x50,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 4,
        ) 


        self.addRemoteVariables(   
            name         = "LocalTrigDropRate",
            offset       =  0x60,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 4,
        ) 

        self.addRemoteVariables(   
            name         = "RemoteTrigDropRate",
            offset       =  0x70,
            bitSize      = 32,
            bitOffset    = 0,
            units        = 'Hz',
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 4,
        )         
        
        self.addRemoteVariables(   
            name         = "LocalTrigCnt",
            offset       =  0x80,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 2,
        )  
        
        self.addRemoteVariables(   
            name         = "RemoteTrigCnt",
            offset       =  0x88,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 2,
        )  

        self.addRemoteVariables(   
            name         = "LocalTrigDropCnt",
            offset       =  0x90,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 2,
        )  
        
        self.addRemoteVariables(   
            name         = "RemoteTrigDropCnt",
            offset       =  0x98,
            bitSize      = 16,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = "RO",
            pollInterval = 1,
            number       = numLanes,
            stride       = 2,
        )          

        self.add(pr.RemoteVariable(
            name         = "CntRst",                 
            description  = "Counter Reset",
            mode         = 'WO',
            offset       = 0xFC,
            hidden       = True,
        ))          
        
    def hardReset(self):
        self.CntRst.set(0x1)

    def softReset(self):
        self.CntRst.set(0x1)

    def countReset(self):
        self.CntRst.set(0x1)        
