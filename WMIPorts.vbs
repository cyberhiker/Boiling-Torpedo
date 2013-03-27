strTargetSnmpDevice = "."
 
Set objWmiLocator = CreateObject("WbemScripting.SWbemLocator")
Set objWmiServices = objWmiLocator.ConnectServer("", "root\snmp\localhost")
 
Set objWmiNamedValueSet = CreateObject("WbemScripting.SWbemNamedValueSet")
objWmiNamedValueSet.Add "AgentAddress", strTargetSnmpDevice
objWmiNamedValueSet.Add "AgentReadCommunityName", "public"
 
Set colTcpConnTable = _
    objWmiServices.InstancesOf("SNMP_RFC1213_MIB_tcpConnTable", , _
        objWmiNamedValueSet)
 
Set colUdpTable = _
    objWmiServices.InstancesOf("SNMP_RFC1213_MIB_udpTable", , _
        objWmiNamedValueSet)
 
 
WScript.Echo "TCP Connections and Listening Ports" & vbCrLf & _
    "-----------------------------------"
 
For Each objTcpConn In colTcpConnTable
    WScript.Echo objTcpConn.tcpConnLocalAddress & ":"    & _
        objTcpConn.tcpConnLocalPort    & " => " & _
            objTcpConn.tcpConnRemAddress   & ":"    & _
                objTcpConn.tcpConnRemPort      & " "    & _
                    "[State: " & objTcpConn.tcpConnState & "]"
Next
 
WScript.Echo vbCrLf & "UDP Ports" & vbCrLf & "---------"
 
For Each objUdp In colUdpTable
    WScript.Echo objUdp.udpLocalAddress & ":" & objUdp.UdpLocalPort
Next