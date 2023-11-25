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
            return true
        }
    }
    return false
}

findMaybe(a, test) {
    return Maybe((&t) => find(a, &t, test))
}

anyMatch(a, test) {
    return find(a, &res, test)
}

allMatch(a, test) {
    return not find(a, &res, negate(test))
}

noneMatch(a, test) {
    return not find(a, &res, test)
}

aRepeat(n, t) {
    a := []
    loop n {
        a.Push(t)
    }
    return a
}

aRepeatBy(n, supplier) {
    a := []
    loop n {
        a.Push(supplier())
    }
    return a
}

aReverse(a) {
    return aMapIndexed(a, (i, t) => a[-i])
}

aGetOr(a, index, default) {
    return index <= a.Length ? a[index] : default
}

aMap(a, mapper) {
    b := []
    for t in a {
        b.Push(mapper(t))
    }
    return b
}

aMapIndexed(a, indexedMapper) {
    b := []
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

join(a, sep := '', mapper?) {
    sq := seqOf(a)
    if IsSet(mapper) {
        sq := sq.map(mapper)
    }
    return sq.join(sep)
}

aSort(a, opt := '') {
    sep := '`n'
    s := Sort(join(a, sep), opt)
    return StrSplit(s, sep)
}

aSortBy(a, mapper, opt := '', interSep := '``') {
    sep := '`n'
    s := Sort(seqof(a).mapIndexed((i, t) => mapper(t) interSep i).join(sep), opt)
    return seqSplit(s, sep).map(t => a[Integer(StrSplit(t, interSep)[2])]).toArray()
}

aSum(a, mapper?) {
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

aMax(a, &res, comparator?) {
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

aMaxBy(a, &res, numMapper, &val?) {
    for t in a {
        v := numMapper(t)
        if not IsSet(res) or val < v {
            res := t
            val := v
        }
    }
    return IsSet(res)
}

aMin(a, &res, comparator?) {
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

aMinBy(a, &res, numMapper, &val?) {
    for t in a {
        v := numMapper(t)
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


class Maybe {
    __New(refCall) {
        this._func := refCall
    }

    map(fun) {
        return Maybe((&t) => (
            this._func.Call(&o),
            IsSet(o) ? t := fun(o) : 0
        ))
    }

    mapOr(fun, o) {
        this._func.Call(&t)
        return IsSet(t) ? fun(t) : o
    }

    mapOrGet(fun, supplier) {
        this._func.Call(&t)
        return IsSet(t) ? fun(t) : supplier()
    }

    orElse(o) {
        this._func.Call(&t)
        return IsSet(t) ? t : o
    }

    orElseGet(supplier) {
        this._func.Call(&t)
        return IsSet(t) ? t : supplier()
    }

    isPresent(&t) {
        this._func.Call(&t)
        return IsSet(t)
    }
}
