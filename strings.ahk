#Include arrays.ahk


startsWith(str, sub) {
    len := StrLen(sub)
    return StrLen(str) >= len and SubStr(str, 1, len) == sub
}

endsWith(str, sub) {
    tot := StrLen(str)
    len := StrLen(sub)
    return tot >= len and SubStr(str, tot - len + 1) == sub
}

surroundedWith(str, left, right) {
    totLen := StrLen(str)
    leftLen := StrLen(left)
    rightLen := StrLen(right)
    return totLen >= leftLen + rightLen
        and SubStr(str, 1, leftLen) == left
        and SubStr(str, totLen - rightLen + 1) == right
}

hasMatch(str, regex) {
    try {
        return RegExMatch(str, regex)
    } catch Error
        return false
}

isWildcardMatch(str, pattern) {
    static wildcardMap := Map(
        '?', '.',
        '*', '.*',
        '.', '\.',
        '+', '\+',
        '(', '\(',
        '[', '\[',
        '{', '\{',
        '\', '\\')
    regex := seqSplit(pattern, '').map(c => wildcardMap.Get(c, c)).join()
    return isFullMatch(str, regex)
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

parseTwo(s, sep, &first, &second, atLastSep := false) {
    if not s {
        first := ''
        return false
    }
    if not atLastSep {
        a := StrSplit(s, sep, ' `t', 2)
        first := a[1]
        if a.Length > 1 {
            second := a[2]
            return true
        } else {
            return false
        }
    } else {
        a := StrSplit(s, sep, ' `t')
        if a.Length == 1 {
            first := a[1]
            return false
        } else if a.Length == 2 {
            first := a[1]
            second := a[2]
            return true
        } else {
            first := range(1, a.Length - 1).map(i => a[i]).join(sep)
            second := a[a.Length]
            return true
        }
    }
}

doCopy(s) {
    A_Clipboard := s or ' '
    ClipWait
}

copySelection() {
    A_Clipboard := ''
    SendInput('^c')
    ClipWait
    return A_Clipboard
}

sRepeat(n, str) {
    acc := ''
    loop n {
        acc .= str
    }
    return acc
}

repr(x) {
    if x is String {
        return x
    }
    if x is Array {
        return '[' join(x, ', ', repr) ']'
    }
    if x is Seq {
        return '(' x.map(repr).join(', ') ')'
    }
    if x is Map {
        return _reprEnum2(x, repr)
    }
    if x is Object {
        return _reprEnum2(x.OwnProps(), repr)
    }
    return String(x)
}


dumps(x) {
    if x is String {
        return '"' StrReplace(x, '\', '\\') '"'
    }
    if x is Array {
        return '[' join(x, ', ', dumps) ']'
    }
    if x is Seq {
        return '[' x.map(dumps).join(', ') ']'
    }
    if x is Map {
        return _reprEnum2(x, dumps)
    }
    if x is Object {
        return _reprEnum2(x.OwnProps(), dumps)
    }
    return String(x)
}

_reprEnum2(e2, formatter) {
    return '{' seqPairs(e2, (k, v) => formatter(k) ': ' formatter(v)).join(', ') '}'
}

nGet(m, key, &num) {
    if mGet(m, key, &value) {
        try {
            num := Number(value)
        } catch TypeError {
        }
    }
    return IsSet(num)
}

nParse(str, &num) {
    try {
        num := Number(str)
    } catch TypeError {
    }
    return IsSet(num)
}


_sys60Table := ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x']

sys60Encode(num) {
    acc := ''
    while num > 0 {
        acc := _sys60Table[Mod(num, _sys60Table.Length) + 1] . acc
        num := num // _sys60Table.Length
    }
    return acc
}

sys60Decode(encoding) {
    static indexMap := toIndexMap(_sys60Table)
    len := _sys60Table.Length
    return seqSplit(encoding, '').fold(0, (acc, c) => acc * len + indexMap[c] - 1)
}

checkTimeFormat(time) {
    if not isFullMatch(time, '[0-9]{14}') {
        throw ValueError('illegal time format: ' time)
    }
}

timeEncode(time) {
    checkTimeFormat(time)
    return sys60Encode(Integer(SubStr(time, 2)))
}

timeDecode(encoding) {
    if not encoding {
        return ''
    }
    s := String(sys60Decode(encoding))
    len := StrLen(s)
    return len == 12 ? '20' s : (len == 13 ? '2' s : s)
}

readableTime(time) {
    if not time {
        return ''
    }
    checkTimeFormat(time)
    return FormatTime(time, "yyyyMMdd HH:mm:ss")
}
