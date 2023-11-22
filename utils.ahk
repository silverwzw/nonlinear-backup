startsWith(str, sub) {
    len := StrLen(sub)
    return StrLen(str) >= len and SubStr(str, 1, len) == sub
}

endsWith(str, sub) {
    tot := StrLen(str)
    len := StrLen(sub)
    return tot >= len and SubStr(str, tot - len + 1) == sub
}

hasMatch(str, regex) {
    try {
        return RegExMatch(str, regex)
    } catch Error
        return false
}

isFullMatch(str, regex) {
    try {
        RegExMatch(str, regex, &res)
        return StrLen(res[]) == StrLen(str)
    } catch Error
        return false
}

matchGet(str, regex, index) {
    try {
        RegExMatch(str, regex, &res)
        return res[index]
    } catch Error
        return ''
}

matchGetAll(str, regex) {
    try {
        RegExMatch(str, regex, &res)
        return res
    } catch Error
        return ''
}

copySelection() {
    A_Clipboard := ''
    SendInput('^c')
    ClipWait
    return A_Clipboard
}

formatArray(a) {
    return '[' join(a, ', ') ']'
}

formatMap(m, valueMapper?) {
    a := []
    for k, v in m {
        a.Push(k ': ' (IsSet(valueMapper) ? valueMapper(v) : v))
    }
    return '{' join(a, ', ') '}'
}


_sys60Table := ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x']
_sys60Map := unset

sys60Encode(num) {
    acc := ''
    while num > 0 {
        acc := _sys60Table[Mod(num, _sys60Table.Length) + 1] . acc
        num := num // _sys60Table.Length
    }
    return acc
}

sys60Decode(encoding) {
    global _sys60Map
    if not IsSet(_sys60Map) {
        _sys60Map := Map()
        forEachIndexed(_sys60Table, (i, c) => _sys60Map[c] := i - 1)
    }
    chars := StrSplit(encoding)
    out := fold(chars, 0, (acc, c) => acc * _sys60Table.Length + _sys60Map[c])
    return out
}
