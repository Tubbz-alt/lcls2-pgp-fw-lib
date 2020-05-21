import pyrogue as pr
import surf.axi
import surf.devices.transceivers

class Kcu1500I2cHw(pr.Device):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        
        self.add(surf.devices.transceivers.Sff8472(
            name = 'QSFP',
            offset = 0x0000)) 
        
        self.add(
            pr.RemoteVariable(
                name = 'MuxSel',
                offset = 0x0800,
                bitSize = 8,
                base = pr.UInt,
                hidden = True,
                enum = {
                    0b00010000 : 'QSFP0',
                    0b00000010 : 'QSFP1'}))



        

            
class Kcu1500I2cProxy(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
        self.add(surf.axi.AxiLiteMasterProxy(
            offset = 0x0000))

        self.AxiLiteMasterProxy.Proxy.add(
            Kcu1500I2cHw())

        self.add(surf.devices.transceivers.Sff8472(
            name = 'QSFP0',
            offset = 0x10000)) 
        
        self.add(surf.devices.transceivers.Sff8472(
            name = 'QSFP1',
            offset = 0x20000)) 
        
    def _doTransaction(self, transaction):
        with self._memLock, transaction.lock():

            # Set the I2C switch to select the correct device
            muxSel = self.AxiLiteMasterProxy.Proxy.MuxSel
            if transaction.address() & 0x1000 == 0x1000:
                if muxSel.valueDisp() != 'QSFP0':
                    muxSel.setDisp('QSFP0', write = True)
            elif transaction.address() & 0x2000 == 0x2000:
                if muxSel.valueDisp() != 'QSFP1':                
                    muxSel.setDisp('QSFP1', write = True)

            addr = transaction.address() & 0x0000
            size = transaction.size()
            typ = transaction.type();
            data = bytearray(size)
            transaction.getData(data)

            # Request a transaction from the proxy
            id = self.AxiLiteMasterProxy.Proxy._reqTransaction(addr, data, size, 0, typ)
            self.AxiLiteMasterProxy.Proxy.waitTransaction(id)

            transaction.done()
