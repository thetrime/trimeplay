Function create_new_packetized_video_listener()
    return {    buffers: []
              read_data: read_packetized_video
           process_data: process_packetized_video
           }
End Function

Function read_packetized_video(context as Object, connection as Object)
    length = connection.getCountRcvBuf()
    buffer = createobject("roByteArray")
    buffer[length-1] = 0
    buffer[length-1] = invalid
    r = connection.receive(buffer, 0, length)
    context.buffers.push(buffer)
    ' initially, lets just log this for analysis
    print "Buffer: " ; buffer.toHexString()
    return false
End Function

Function process_packetized_video(context as Object, connection as Object)
    stop
End Function