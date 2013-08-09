Function handle_fairplay(rtsp as Object, connection as Object)
    reply = createobject("roByteArray")
    fply_header = createobject("roByteArray")
    payload = createobject("roByteArray")
    print rtsp.headers
    print rtsp.body.toHexString()
    for i = 1 to 12
        fply_header.push(rtsp.body.Shift())
    end for
    for each byte in rtsp.body 
        payload.push(byte)
    end for
    print "fply seq:" ; fply_header[6] ; " len" ; fply_header[11]
    fairplay_seq = fply_header[6]
    if fairplay_seq = 1 then
        'print payload
        print "Sending fairplay response for " ; payload[2]
        packet = createobject("roByteArray")
        sane_append(packet, [70, 80, 76, 89, 3, 1, 2, 0, 0, 0, 0, 130, 2, 2, 60, 40, 74, 225, 106, 20, 172, 73, 178, 149, 250, 154, 240, 93, 231, 76, 78, 105, 196, 164, 30, 241, 112, 135, 162, 189, 114, 115, 152, 102, 194, 90, 3, 48, 20, 38, 247, 38, 213, 167, 167, 52, 232, 247, 136, 112, 118, 244, 250, 55, 57, 78, 3, 104, 115, 11, 252, 138, 63, 31, 130, 78, 16, 175, 47, 92, 27, 159, 170, 152, 194, 187, 19, 104, 163, 181, 81, 164, 216, 28, 33, 59, 2, 78, 84, 7, 70, 6, 229, 52, 247, 148, 157, 16, 198, 83, 50, 42, 178, 206, 186, 149, 187, 146, 247, 29, 221, 128, 177, 13, 59, 96, 65, 47, 70, 192, 4, 69, 5, 44, 208, 167, 49, 140, 207, 37, 205, 183])
        'sane_append(packet, [70, 80, 76, 89, 2, 1, 2, 0, 0, 0, 0, 130, 2, payload[2], 47, 123, 105, 230, 178, 126, 187, 240, 104, 95, 152, 84, 127, 55, 206, 207, 135, 6, 153, 110, 126, 107, 15, 178, 250, 113, 32, 83, 227, 148, 131, 218, 34, 199, 131, 160, 114, 64, 77, 221, 65, 170, 61, 76, 110, 48, 34, 85, 170, 162, 218, 30, 180, 119, 131, 140, 121, 213, 101, 23, 195, 250, 1, 84, 51, 158, 227, 130, 159, 48, 240, 164, 143, 118, 223, 119, 17, 126, 86, 158, 243, 149, 232, 226, 19, 179, 30, 182, 112, 236, 90, 138, 242, 106, 252, 188, 137, 49, 230, 126, 232, 185, 197, 242, 199, 29, 120, 243, 239, 141, 97, 247, 59, 204, 23, 195, 64, 35, 82, 74, 139, 156, 177, 117, 5, 102, 230, 179])
        print "Length: " ; packet.Count()
        'print packet
        status = send_generic_reply(rtsp.version, connection, "application/octet-stream", packet)
    else if fairplay_seq = 3 then
        print "Sending second fairplay packet"
        packet = createobject("roByteArray")
        'sane_append(packet, [70, 80, 76, 89, 2, 1, 4, 0, 0, 0, 0, 20])
        sane_append(packet, [70, 80, 76, 89, 3, 1, 4, 0, 0, 0, 0, 20])
        ' Now copy the last 20 bytes of the body
        for i = rtsp.body.Count() - 20 to rtsp.body.Count() - 1
            packet.push(rtsp.body[i])
        end for
        status = send_generic_reply(rtsp.version, connection, "application/octet-stream", packet)
    else
        packet = "RTSP/1.1 404 Not Found" + chr(13) + chr(10) + chr(13) + chr(10)
        reply.fromAsciiString(packet)
        status = connection.send(reply, 0, reply.Count())
    end if
    return status    
End Function


Function send_rtsp_reply(connection as Object, content_type as String, data as Object)
    return send_generic_reply("RTSP/1.0", connection, content_type, data)
End Function

Function send_generic_reply(mode as String, connection as Object, content_type as String, data as Object)
    reply = createobject("roByteArray")
    date = createobject("roDateTime")
    months = ["placeholder"
              "Jan"
              "Feb"
              "Mar"
              "Apr"
              "May"
              "Jun"
              "Jul"
              "Aug"
              "Sep"
              "Oct"
              "Nov"
              "Dec"]
    month_name = months[date.getMonth()]
    ' WHY does str(6) return " 6" ?!
    rfc822 = Left(date.GetWeekday(), 3) + ", " + pad_integer(date.GetDayOfMonth()) + " " + month_name + " " + right(str(date.getYear()), 4) + " " + pad_integer(date.getHours()) + ":" + pad_integer(date.getMinutes()) + ":" + pad_integer(date.getSeconds()) + " GMT"
    if mode = "HTTP/1.1" then
        mode = "HTTP/1.0"
    end if
    packet = mode + " 200 OK" + chr(13) + chr(10)
    'if mode = "RTSP/1.0" Then
       packet = packet + "X-Apple-ET: 32" + chr(13) + chr(10)
    'end if
    packet = packet + "Content-Type: " + content_type + chr(13) + chr(10)
    if mode = "RTSP/1.0" Then
        packet = packet + "CSeq: 0" + chr(13) + chr(10)
    end if
    'packet = packet + "Date: " + rfc822 + chr(13) + chr(10)    
    packet = packet + "Server: AirTunes/150.33" + chr(13) + chr(10)
    packet = packet + "Content-Length: " + data.Count().toStr() + chr(13) + chr(10) + chr(13) + chr(10)
    reply.fromAsciiString(packet)
    print packet
    sane_append(reply, data)
    print reply.toHexString()
    status = connection.send(reply, 0, reply.Count())
    return status
End Function

Function sane_append(dst as Object, src as Object)
    For each x in src
        dst.push(x)
    end for
End Function

