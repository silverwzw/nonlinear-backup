#Include seq.ahk

Array.Prototype.Base := NewArray
class NewArray extends Iterable {
    static mapOut(mapper) {
        b := []
        b.Capacity := this.Capacity
        for t in this {
            b.Push(mapper(t))
        }
        return b
    }

    static mapIndexedOut(indexedMapper) {
        b := []
        b.Capacity := this.Capacity
        for i, t in this {
            b.Push(indexedMapper(i, t))
        }
        return b
    }

    static first(&res) {
        if this.Length > 1 {
            res := this[1]
            return true
        }
        return false
    }

    static toArr() {
        return this.Clone()
    }

    static reverse() {
        return range(this.Length, 1, -1).map(i => this[i])
    }

    static reverseOut() {
        return range(this.Length, 1, -1).mapOut(i => this[i])
    }

    static get(index, default) {
        return index <= this.Length ? this[index] : default
    }

    static slice(start, end) {
        return this.sub(start, end).toArr()
    }

    static sub(start, end) {
        b := start >= 0 ? start : this.Length + start + 1
        e := end >= 0 ? end : this.Length + end + 1
        return range(b, e, b <= e ? 1 : -1).map(i => this[i])
    }
}

Map.Prototype.Base := NewMap
class NewMap extends Iterable {
    static getVal(key, &value) {
        if this.Has(key) {
            value := this[key]
            return true
        }
        return false
    }

    static getNum(key, &num) {
        if this.getVal(key, &value) {
            try {
                num := Number(value)
            } catch TypeError {
            }
        }
        return IsSet(num)
    }

    static seq(kvMapper) {
        return seqPairs(this, kvMapper)
    }
}

arrRepeat(n, t) {
    a := []
    loop n {
        a.Push(t)
    }
    return a
}

arrRepeatBy(n, supplier) {
    a := []
    loop n {
        a.Push(supplier())
    }
    return a
}

itemGet(x) {
    if HasProp(x, '__Item') {
        return t => x[t]
    }
    throw TypeError('Unsupported type: ' Type(x))
}

isIn(x) {
    if x is Map or x is Array {
        return t => x.Has(t)
    }
    if x is CallbackSeq or x is EnumSeq {
        return t => x.any(e => e == t)
    }
    if x is String {
        return InStr.Bind(x)
    }
    throw TypeError('Unsupported type: ' Type(x))
}

notIn(x) {
    if x is Map or x is Array {
        return t => not x.Has(t)
    }
    if x is CallbackSeq or x is EnumSeq {
        return t => x.none(e => e == t)
    }
    if x is String {
        return t => not InStr(x, t)
    }
    throw TypeError('Unsupported type: ' Type(x))
}

moveWhile(t, unaryMapper, condition) {
    while condition(t) {
        t := unaryMapper(t)
    }
    return t
}

moveUntil(t, unaryMapper, condition) {
    loop {
        t := unaryMapper(t)
    } until condition(t)
    return t
}
