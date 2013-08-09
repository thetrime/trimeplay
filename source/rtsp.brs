Function dispatch_rtsp(rtsp as Object, connection as Object)
    print "Handling RTSP: " ; rtsp.method ; " -> " ;rtsp.path
    If rtsp.path = "/fp-setup" Then
        status = handle_fairplay(rtsp, connection)
    else if rtsp.method = "announce" Then
        status = handle_announce(rtsp, connection)
    else if rtsp.method = "setup" Then
        status = handle_setup(rtsp, connection)
    else if rtsp.method = "record" Then
        status = handle_record(rtsp, connection)
    else if rtsp.method = "set_parameter" Then
        status = handle_set_parameter(rtsp, connection)
    else if rtsp.method = "get_parameter" Then
        status = handle_get_parameter(rtsp, connection)
    else
        print rtsp
        'stop
        ignore_anything_else(connection)
    End If
    print "Status: " ; status
    return false
End Function


Function ignore_anything_else(connection as Object)
    reply = createobject("roByteArray")
    packet = "RTSP/1.0 500 Not Implemented" + chr(13) + chr(10)
    packet = packet + "Server: AirTunes/150.33" + chr(13) + chr(10)
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function

Function handle_announce(rtsp as Object, connection as Object)
    print rtsp.headers
    print rtsp.body.toAsciiString()
    reply = createobject("roByteArray")
    packet = "RTSP/1.0 200 OK" + chr(13) + chr(10)
    packet = packet + "Server: AirTunes/150.33" + chr(13) + chr(10)
    'packet = packet + "Audio-Jack-Status: connected; type=analog" + chr(13) + chr(10)
    packet = packet + "CSeq: " + rtsp.headers["CSeq"] + chr(13) + chr(10) + chr(13) + chr(10)
    print packet
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function

Function handle_setup(rtsp as Object, connection as Object)
    print rtsp.headers
    packet = "RTSP/1.0 200 OK" + chr(13) + chr(10)
    packet = packet + "Server: AirTunes/150.33" + chr(13) + chr(10)
    if rtsp.path.right(5) = "video" then
        packet = packet + "Transport: RTP/AVP/TCP;unicast;mode=record;server_port=7001" + chr(13) + chr(10)
    else if rtsp.path.right(5) = "audio" then
        packet = packet + "Audio-Jack-Status: connected; type=analog" + chr(13) + chr(10)
        packet = packet + "Session: DEADBEEF" + chr(13) + chr(10)
        packet = packet + "Transport: RTP/AVP/UDP;unicast;mode=record;server_port=6009;control_port=6010;timing_port=6011;event_port=49154" + chr(13) + chr(10) 
    else
        print rtsp.path
        stop
    end if
    reply = createobject("roByteArray")
    packet = packet + "CSeq: " + rtsp.headers["CSeq"] + chr(13) + chr(10) + chr(13) + chr(10)
    print packet
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function

Function handle_record(rtsp as Object, connection as Object)
    print rtsp.headers
    reply = createobject("roByteArray")
    packet = "RTSP/1.0 200 OK" + chr(13) + chr(10)
    packet = packet + "Server: AirTunes/150.33" + chr(13) + chr(10)
    packet = packet + "Audio-Jack-Status: connected; type=analog" + chr(13) + chr(10)
    packet = packet + "Audio-Latency: 960" + chr(13) + chr(10)
    packet = packet + "CSeq: " + rtsp.headers["CSeq"] + chr(13) + chr(10) + chr(13) + chr(10)
    print packet
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function

Function handle_set_parameter(rtsp as Object, connection as Object)
    print rtsp.headers
    reply = createobject("roByteArray")
    packet = "RTSP/1.0 200 OK" + chr(13) + chr(10)
    packet = packet + "Server: AirTunes/150.33" + chr(13) + chr(10)
    packet = packet + "CSeq: " + rtsp.headers["CSeq"] + chr(13) + chr(10) + chr(13) + chr(10)
    print packet
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function

Function handle_get_parameter(rtsp as Object, connection as Object)
    print rtsp.headers
    reply = createobject("roByteArray")
    packet = "RTSP/1.0 200 OK" + chr(13) + chr(10)
    packet = packet + "Server: AirTunes/150.33" + chr(13) + chr(10)
    packet = packet + "volume: 0.000000" + chr(13) + chr(10)
    packet = packet + "CSeq: " + rtsp.headers["CSeq"] + chr(13) + chr(10) + chr(13) + chr(10)
    print packet
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status
End Function