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

find(a, &res, test) {
    for t in a {
        if test(t) {
            res := t
            break
        }
    }
}

anyMatch(a, test) {
    find(a, &res, test)
    return IsSet(res)
}

allMatch(a, test) {
    find(a, &res, negate(test))
    return not IsSet(res)
}

noneMatch(a, test) {
    find(a, &res, test)
    return not IsSet(res)
}

repeat(n, t) {
    a := []
    loop n {
        a.Push(t)
    }
    return a
}

gen(n, supplier) {
    a := []
    loop n {
        a.Push(supplier())
    }
    return a
}

reverse(a) {
    return amapIndexed(a, (i, t) => a[-i])
}

amap(a, mapper) {
    b := []
    for t in a {
        b.Push(mapper(t))
    }
    return b
}

amapIndexed(a, indexedMapper) {
    b := []
    for i, t in a {
        b.Push(indexedMapper(i, t))
    }
    return b
}

join(a, sep := '') {
    return Seq.of(a).join(sep)
}

asort(a, opt := '') {
    sep := '`n'
    s := Sort(join(a, sep), opt)
    return StrSplit(s, sep)
}

asortBy(a, mapper, opt := '', interSep := '``') {
    sep := '`n'
    s := Sort(Seq.of(a).mapIndexed((i, t) => mapper(t) interSep i).join(sep), opt)
    return Seq.split(s, sep).map(t => a[Integer(StrSplit(t, interSep)[2])]).toArray()
}

asum(a, mapper?) {
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

amax(a, &res, comparator?) {
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
}

amaxBy(a, &res, numMapper, &val?) {
    for t in a {
        v := numMapper(t)
        if not IsSet(res) or val < v {
            res := t
            val := v
        }
    }
}

amin(a, &res, comparator?) {
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
}

aminBy(a, &res, numMapper, &val?) {
    for t in a {
        v := numMapper(t)
        if not IsSet(res) or val > v {
            res := t
            val := v
        }
    }
}
