#Include arrays.ahk

extendClass(String, NewString)
class NewString {
    static startsWith(sub) {
        len := StrLen(sub)
        return StrLen(this) >= len and SubStr(this, 1, len) == sub
    }

    static endsWith(sub) {
        tot := StrLen(this)
        len := StrLen(sub)
        return tot >= len and SubStr(this, tot - len + 1) == sub
    }

    static surroundedWith(left, right) {
        totLen := StrLen(this)
        leftLen := StrLen(left)
        rightLen := StrLen(right)
        return totLen >= leftLen + rightLen
            and SubStr(this, 1, leftLen) == left
            and SubStr(this, totLen - rightLen + 1) == right
    }

    static has(sub) {
        return InStr(this, sub)
    }

    static hasMatch(regex) {
        try {
            return RegExMatch(this, regex)
        } catch Error
            return false
    }

    static isWildcardMatch(pattern) {
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
        return this.isFullMatch(regex)
    }

    static isFullMatch(regex) {
        try {
            RegExMatch(this, regex, &res)
            return StrLen(res[]) == StrLen(this)
        } catch Error
            return false
    }

    static matchGet(regex, index) {
        try {
            RegExMatch(this, regex, &res)
            return res[index]
        } catch Error
            return ''
    }

    static matchGetAll(regex) {
        try {
            RegExMatch(this, regex, &res)
            return res
        } catch Error
            return ''
    }

    static splitTwoParts(sep, &first, &second, byLastSep := false) {
        if not this {
            first := ''
            return false
        }
        if not byLastSep {
            a := StrSplit(this, sep, ' `t', 2)
            first := a[1]
            if a.Length > 1 {
                second := a[2]
                return true
            } else {
                return false
            }
        } else {
            a := StrSplit(this, sep, ' `t')
            if a.Length == 1 {
                first := a[1]
                return false
            } else if a.Length == 2 {
                first := a[1]
                second := a[2]
                return true
            } else {
                first := a.sub(1, -2).join(sep)
                second := a[a.Length]
                return true
            }
        }
    }

    static toNumber(&num) {
        try {
            num := Number(this)
        } catch TypeError {
        }
        return IsSet(num)
    }
}

strRepeat(n, str) {
    acc := str
    loop n - 1 {
        acc .= str
    }
    return acc
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

repr(x) {
    if x is String {
        return x
    }
    if x is Array {
        return '[' x.join(', ', repr) ']'
    }
    if x is Map {
        return _reprEnum2(x, repr)
    }
    if x is CallbackSeq or x is EnumSeq {
        return '(' x.join(', ', repr) ')'
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
        return '[' x.join(', ', dumps) ']'
    }
    if x is Map {
        return _reprEnum2(x, dumps)
    }
    if x is CallbackSeq or x is EnumSeq {
        return '(' x.join(', ', dumps) ')'
    }
    if x is Object {
        return _reprEnum2(x.OwnProps(), dumps)
    }
    return String(x)
}

_reprEnum2(e2, formatter) {
    return '{' seqPairs(e2, (k, v) => formatter(k) ': ' formatter(v)).join(', ') '}'
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
    static indexMap := _sys60Table.toIndexMap()
    len := _sys60Table.Length
    return seqSplit(encoding, '').fold(0, (acc, c) => acc * len + indexMap[c] - 1)
}

checkTimeFormat(time) {
    if not time.isFullMatch('[0-9]{14}') {
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
