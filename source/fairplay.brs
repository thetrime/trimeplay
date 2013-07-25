Function handle_fairplay(http as Object, connection as Object)
    print http.headers
    print http.body
    return send_http_reply(connection, "application/octet-stream", 
    reply = createobject("roByteArray")
    packet = "HTTP/1.1 404 Not Found" + chr(13) + chr(10)
    reply.fromAsciiString(packet)
    status = connection.send(reply, 0, reply.Count())
    return status    
End Function
