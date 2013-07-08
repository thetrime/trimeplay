' This code is based on the puff implementation provided with zlib.

Function BitStream(raw as Object)
    return {  raw: raw
         read_bit: read_bit
        read_bits: read_bits
        read_bool: read_bool
             byte: 0
             mask: 256 }
End Function

Function fixed_tree()
    lengths = []
    if m.fixed_tree <> invalid then
        return m.fixed_tree
    end if
    ' Fill in the pre-defined lengths
    for s = 0 to 143
        lengths[s] = 8
    end for
    for s = 144 to 255
        lengths[s] = 9
    end for
    for s = 256 to 279
        lengths[s] = 7
    end for
    for s = 280 to 287
        lengths[s] = 8
    end for
    code_tree = make_tree(lengths, 0, 288)
    if code_tree.status <> 0 then
        stop
    end if
    for s = 0 to 29
        lengths[s] = 5
    end for
    dist_tree = make_tree(lengths, 0, 30)
    'if dist_tree.status <> 0 then
    '    stop
    'end if

    m.fixed_tree = {code_tree: code_tree, dist_tree: dist_tree}
    return m.fixed_tree
End Function


Function read_bit()
    if m.read_bool() then
        return 1
    else
       return 0
    end if
End Function

Function read_bool()
    if m.mask = 256 then
        m.byte = m.raw.Shift()
        m.mask = 1
    end if
    bit = ((m.byte and m.mask) = m.mask)
    m.mask = m.mask * 2
    return bit
End Function

Function read_bits(n as Integer)
    result = 0
    f = 1
    For i = 1 to n step 1
        b = m.read_bit()
        result = result + f * b
        f = f * 2
    End For
    return result
End Function

Function inflate(raw as Object)
    output = createobject("roByteArray")
    stream = BitStream(raw)
    while true
        ' Read header
        last = stream.read_bool()
        format = stream.read_bits(2)
        if format = 0 then
            uncompressed_block(stream, output)
        else if format = 1 then
            static_block(stream, output)
        else if format = 2 then
            dynamic_block(stream, output)
        else
            print "Error in stream. Type 11 is illegal"
            stop
        end if
        if last then
            return output
        end if
    end while    
End Function

Function dynamic_block(stream as Object, output as Object)
    ' Read the trees. First is information about the tree sizes
    literal_length = stream.read_bits(5) + 257
    distance_length = stream.read_bits(5) + 1
    length_length = stream.read_bits(4) + 4
    lengths = []

    ' Now read out the length-lengths, in their carefully designed order
    i = 0
    For each index in [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
        if i < length_length then
            lengths[index] = stream.read_bits(3)
        else
            lengths[index] = 0
        end if
        i = i + 1
    End For

    length_tree = make_tree(lengths, 0, 19)
    if length_tree.status <> 0 then
        print lengths
        stop
    end if

    ' Now read the length/literal and distance code trees
    i = 0
    while i < literal_length + distance_length
        symbol = decode(stream, length_tree)
        if symbol < 16 then    ' Normal symbol
            lengths[i] = symbol
            symbol = symbol + 1            
            i = i + 1
        else              ' Repeats
            l = 0
            if symbol = 16 then ' Repeat last code
                l = lengths[i-1]
                symbol = 3 + stream.read_bits(2)                
            else if symbol = 17 then ' Zeros
                symbol = 3 + stream.read_bits(3)                
            else if symbol = 18 then ' Lots of Zeros
                symbol = 11 + stream.read_bits(7)
            end if
            for z = 1 to symbol step 1
                lengths[i] = l
                i = i + 1
            end for
        end if
    End While

    if lengths[256] = 0 then
        stop
    end if

    code_tree = make_tree(lengths, 0, literal_length)
    dist_tree = make_tree(lengths, literal_length, distance_length)
    ' Use the trees to decode the block
    decode_block(stream, code_tree, dist_tree, output)
End Function

Function static_block(stream as Object, output as Object)
    tree = fixed_tree()
    ' Use the tree to decode the block
    decode_block(stream, tree.code_tree, tree.dist_tree, output)
End Function

Function uncompressed_block(stream as Object, output as Object)
    ' Discard bits
    stream.mask = 256
    
    length = stream.raw.Shift()
    length = length * 256 + stream.raw.Shift()
    nlength = stream.raw.Shift()
    nlength = nlength * 256 + stream.raw.Shift()
    ' In theory we should check that nlength = ~length. But I cannot be bothered
    for i = 1 to length
        output.push(stream.raw.shift())
    end for
    
End Function

Function make_tree(lengths as Object, start as Integer, n as Integer)
    count = []
    symbol = []
    for i = 0 to 15 Step 1
        count[i] = 0
    End for
    for s = 0 to n-1 step 1
        count[lengths[start + s]] = count[lengths[start + s]] + 1
    end for
    if count[0] = n then
        print "No codes?"
        return { count: invalid
                symbol: invalid
                status: 0}
    end if
    l = 1    
    for i = 1 to 15 Step 1
        l = l * 2
        l = l - count[i]
        if l < 0 then
            print "Incomplete codes" ; l
            return { count: invalid
                    symbol: invalid
                    status: l}
        end if
    End for
    offs = []
    offs[1] = 0
    for i = 1 to 14 step 1
        offs[i+1] = offs[i] + count[i]
    end for

    for s = 0 to n-1 step 1
        if lengths[start + s] <> 0 then        
            symbol[offs[lengths[start + s]]] = s
            offs[lengths[start + s]] = offs[lengths[start + s]] + 1
        end if
    end for
    return { count: count
            symbol: symbol
            status: l}
End Function


Function decode_block(stream as Object, code_tree as Object, dist_tree as Object, output as Object)
    lens = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    lext = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    dists = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
    dext = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]

    while true
        symbol = decode(stream, code_tree)
        if symbol = 256 then
            return 0
        else if symbol < 0 then
            ' decode error
            stop
        else if symbol < 256 then
            ' Sweet. Got a symbol
            output.push(symbol)
        else
            ' distance + length copy
            symbol = symbol - 257
            if symbol >= 29 then
                ' invalid code
                stop
            end if
            copy_length = lens[symbol] + stream.read_bits(lext[symbol])
    
            ' Now get how far back to copy from
            symbol = decode(stream, dist_tree)
            if symbol < 0 then
                ' invalid distance
                stop
            end if
            dist = dists[symbol] + stream.read_bits(dext[symbol])
            start = output.count() - dist
            for z = 0 to copy_length - 1
                output.push(output[start + z])
            end for
        end if        
    End While
End Function

Function decode(stream as Object, tree as Object)
    code = 0
    index = 0
    first = 0
    for l = 1 to 15
        code = (code or stream.read_bit())
        count = tree.count[l]
        if code - count < first then
            return tree.symbol[index + (code - first)]
        end if
        index = index + count
        first = first + count
        first = first * 2
        code = code * 2
    end for
    ' Out of codes :(    
    stop
End Function

Function ztest()
    'print inflate([10, 201, 200, 44, 86, 0, 162, 68, 133, 146, 212, 226, 18, 0, 0, 0, 0, 255, 255, 3, 0]).toAsciiString()
    print inflate([12,200,177,13,192,48,0,2,176,95,43,65,8,116,67,252,223,122,116,13,241,174,178,30,100,116,131,137,113,255,207,212,139,87,92,15,24,213,56,76,193,15,0,0,255,255,3,0]).toAsciiString()
    stop
End Function