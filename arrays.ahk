#Include seq.ahk


fold(a, acc, accumulator) {
    forEach(a, t => acc := accumulator(acc, t))
    return acc
}

forEach(a, consumer) {
    for t in a {
        consumer(t)
    }
}

forEachIndexed(a, indexedConsumer) {
    for i, t in a {
        indexedConsumer(i, t)
    }
}

first(a, &res) {
    for t in a {
        res := t
        return true
    }
    return false
}

find(a, &res, test) {
    for t in a {
        if test(t) {
            res := t
            return true
        }
    }
    return false
}

anyMatch(a, test) {
    return find(a, &_, test)
}

allMatch(a, test) {
    return not find(a, &_, negate(test))
}

noneMatch(a, test) {
    return not find(a, &_, test)
}

repeat(n, t) {
    a := []
    loop n {
        a.Push(t)
    }
    return a
}

repeatBy(n, supplier) {
    a := []
    loop n {
        a.Push(supplier())
    }
    return a
}

reverse(a) {
    return aMapIndexed(a, (i, t) => a[-i])
}

getOr(a, index, default) {
    return index <= a.Length ? a[index] : default
}

aMap(a, mapper) {
    b := []
    if a is Array {
        b.Capacity := a.Capacity
    }
    for t in a {
        b.Push(mapper(t))
    }
    return b
}

aMapIndexed(a, indexedMapper) {
    b := []
    if a is Array {
        b.Capacity := a.Capacity
    }
    for i, t in a {
        b.Push(indexedMapper(i, t))
    }
    return b
}

filter(a, test) {
    b := []
    for t in a {
        if test(t) {
            b.Push(t)
        }
    }
    return b
}

join(a, sep?, mapper?) {
    sq := seqOf(a)
    if IsSet(mapper) {
        sq := sq.map(mapper)
    }
    return sq.join(sep?)
}

aSort(a, opt := '') {
    sep := '`n'
    s := Sort(join(a, sep), opt)
    return StrSplit(s, sep)
}

aSortBy(a, mapper, opt := '', interSep := '``') {
    sep := '`n'
    s := Sort(seqOf(a).mapIndexed((i, t) => mapper(t) interSep i).join(sep), opt)
    return seqSplit(s, sep).map(t => a[Integer(StrSplit(t, interSep)[2])]).toArray()
}

toIndexMap(a, keyMapper?) {
    m := Map()
    IsSet(keyMapper)
    ? forEachIndexed(a, (i, t) => m[keyMapper(t)] := i)
    : forEachIndexed(a, (i, t) => m[t] := i)
    return m
}

count(a, test) {
    c := 0
    for t in a {
        if test(t) {
            c++
        }
    }
    return c
}

sum(a, mapper?) {
    sum := 0
    if IsSet(mapper) {
        for t in a {
            sum += mapper(t)
        }
    } else {
        for t in a {
            sum += t
        }
    }
    return sum
}

maxOf(a, &res, comparator?) {
    if IsSet(comparator) {
        for t in a {
            if not IsSet(res) or comparator(res, t) < 0 {
                res := t
            }
        }
    } else {
        for t in a {
            if not IsSet(res) or res < t {
                res := t
            }
        }
    }
    return IsSet(res)
}

maxBy(a, &res, valMapper, &val?) {
    for t in a {
        v := valMapper(t)
        if not IsSet(res) or val < v {
            res := t
            val := v
        }
    }
    return IsSet(res)
}

minOf(a, &res, comparator?) {
    if IsSet(comparator) {
        for t in a {
            if not IsSet(res) or comparator(res, t) > 0 {
                res := t
            }
        }
    } else {
        for t in a {
            if not IsSet(res) or res > t {
                res := t
            }
        }
    }
    return IsSet(res)
}

minBy(a, &res, valMapper, &val?) {
    for t in a {
        v := valMapper(t)
        if not IsSet(res) or val > v {
            res := t
            val := v
        }
    }
    return IsSet(res)
}

mGet(m, key, &value) {
    if m.Has(key) {
        value := m[key]
        return true
    }
    return false
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
    if x is Enumerator {
        return t => anyMatch(x, e => e == t)
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
    if x is Array or x is Enumerator {
        return t => noneMatch(x, e => e == t)
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
