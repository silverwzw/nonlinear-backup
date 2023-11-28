class StopError extends ValueError {
}
_stopError := StopError()

_arrayPusher(a, t) {
    return a.Push(t)
}

_strConcat(acc, s) {
    return acc s
}

stop() {
    throw _stopError
}

negate(test) {
    return x => !test(x)
}

class Seq {
    __New(consumerConsumer) {
        this.consumerConsumer := consumerConsumer
    }

    consume(consumer) {
        try
            this.consumerConsumer.Call(consumer)
        catch StopError as e {
        }
    }

    fold(acc, accumulator) {
        this.consume(t => acc := accumulator(acc, t))
        return acc
    }

    reduce(des, reducer) {
        this.consume(t => reducer(des, t))
        return des
    }

    consumeIndexed(indexedConsumer) {
        i := 1
        this.consume(t => indexedConsumer(i++, t))
        return i
    }

    map(mapper) {
        return Seq(c => this.consume(t => c(mapper(t))))
    }

    mapIndexed(indexedMapper) {
        fun(c) {
            i := 1
            this.consume(t => c(indexedMapper(i++, t)))
        }
        return Seq(fun)
    }

    onEach(consumer) {
        return Seq(c => this.consume(t => (consumer(t), c(t))))
    }

    filter(test) {
        return Seq(c => this.consume(t => test(t) ? c(t) : 0))
    }

    take(n) {
        return Seq(c => this.consumeIndexed((i, t) => i <= n ? c(t) : stop()))
    }

    drop(n) {
        return this.partial(t => 0, n)
    }

    partial(consumer, n := 1) {
        return Seq(c => this.consumeIndexed((i, t) => (i > n ? c : consumer).Call(t)))
    }

    takeWhile(test) {
        return Seq(c => this.consume(t => test(t) ? c(t) : stop()))
    }

    dropWhile(test) {
        fun(c) {
            done := false
            g(t) {
                if done {
                    c(t)
                } else if not test(t) {
                    c(t)
                    done := true
                }
            }
            this.consume(g)
        }
        return Seq(fun)
    }

    chunked(n) {
        fun(c) {
            a := []
            g(t) {
                if a.Length >= n {
                    c(a)
                    a := []
                }
                a.Push(t)
            }
            this.consume(g)
            if a.Length > 0 {
                c(a)
            }
        }
        return Seq(fun)
    }

    flatMap(toSeqMapper) {
        return Seq(c => this.consume(t => toSeqMapper(t).consume(c)))
    }

    runningFold(init, mapper) {
        fun(c) {
            cur := init
            this.consume(t => c(cur := mapper(t, cur)))
        }
        return Seq(fun)
    }

    append(t*) {
        this.appendAll(t)
    }

    appendAll(a) {
        fun(c) {
            this.consume(c)
            for t in a {
                c(a)
            }
        }
        return Seq(fun)
    }

    any(test, ifFound := true) {
        return this.find(&res, test)
    }

    all(test) {
        return not this.find(&res, negate(test))
    }

    none(test) {
        return not this.find(&res, test)
    }

    first(&res) {
        fun(t) {
            res := t
            stop()
        }
        this.consume(fun)
        return IsSet(res)
    }

    firstMaybe() {
        return Maybe(this.first)
    }

    find(&res, test) {
        fun(t) {
            if test(t) {
                res := t
                stop()
            }
        }
        this.consume(fun)
        return IsSet(res)
    }

    findMaybe(test) {
        return Maybe((&t) => this.find(&t, test))
    }

    count(test?) {
        return IsSet(test) ? this.sum(t => test(t) ? 1 : 0) : this.sum(t => 1)
    }

    sum(numMapper?) {
        res := 0
        if IsSet(numMapper) {
            this.consume(t => res += numMapper(t))
        } else {
            this.consume(t => res += t)
        }
        return res
    }

    average(numMapper, weightMapper?) {
        sum := 0
        weight := 0
        if IsSet(weightMapper) {
            ifWeighted(t) {
                v := numMapper(t)
                w := weightMapper(t)
                sum += v * w
                weight += w
            }
            this.consume(ifWeighted)
        } else {
            notWeighted(t) {
                sum += numMapper(t)
                weight++
            }
            this.consume(notWeighted)
        }
        return weight > 0 ? sum / weight : 0
    }

    max(&res, comparator?) {
        if IsSet(comparator) {
            ifCmp(t) {
                if not IsSet(res) or comparator(res, t) < 0 {
                    res := t
                }
            }
            this.consume(ifCmp)
        } else {
            nonCmp(t) {
                if not IsSet(res) or res < t {
                    res := t
                }
            }
            this.consume(nonCmp)
        }
        return IsSet(res)
    }

    maxBy(&res, numMapper, &val?) {
        fun(t) {
            v := numMapper(t)
            if not IsSet(res) or val < v {
                res := t
                val := v
            }
        }
        this.consume(fun)
        return IsSet(res)
    }

    min(&res, comparator?) {
        if IsSet(comparator) {
            ifCmp(t) {
                if not IsSet(res) or comparator(res, t) > 0 {
                    res := t
                }
            }
            this.consume(ifCmp)
        } else {
            nonCmp(t) {
                if not IsSet(res) or res > t {
                    res := t
                }
            }
            this.consume(nonCmp)
        }
        return IsSet(res)
    }

    minBy(&res, numMapper, &val?) {
        fun(t) {
            v := numMapper(t)
            if not IsSet(res) or val > v {
                res := t
                val := v
            }
        }
        this.consume(fun)
        return IsSet(res)
    }

    sort(opt := '') {
        sep := '`n'
        s := Sort(this.join(sep), opt)
        return seqSplit(s, sep)
    }

    sortBy(mapper, opt := '', interSep := '``') {
        sep := '`n'
        a := this.toArray()
        s := Sort(this.mapIndexed((i, t) => mapper(t) interSep i).join(sep), opt)
        return seqSplit(s, sep).map(t => a[Integer(StrSplit(t, interSep)[2])])
    }

    reverse() {
        return seqReverse(this.toArray())
    }

    toArray() {
        return this.reduce([], _arrayPusher)
    }

    partition(test, &part1, &part2) {
        part1 := []
        part2 := []
        this.consume(t => (test(t) ? part1 : part2).Push(t))
    }

    cache() {
        return seqOf(this.toArray())
    }

    toMap(keyMapper, valueMapper) {
        return this.reduce(Map(), (m, x) => m[keyMapper(x)] := valueMapper(x))
    }

    toMapBy(keyMapper) {
        return this.reduce(Map(), (m, x) => m[keyMapper(x)] := x)
    }

    toMapWith(valueMapper) {
        return this.reduce(Map(), (m, x) => m[x] := valueMapper(x))
    }

    groupBy(toKey, valueMapper?) {
        res := Map()
        fun(t) {
            key := toKey(t)
            if not res.Has(key) {
                res[key] := ls := []
            } else {
                ls := res[key]
            }
            ls.Push(IsSet(valueMapper) ? valueMapper(t) : t)
        }
        this.consume(fun)
        return res
    }

    join(sep?) {
        if IsSet(sep) and sep {
            rest := false
            fun(acc, t) {
                if rest
                    return acc sep t
                else {
                    rest := true
                    return t
                }
            }
            return this.fold('', fun)
        } else {
            return this.fold('', _strConcat)
        }
    }
}

seqOf(a) {
    return a is Array ? ArraySeq(a) : ItrSeq(a)
}

seqAll(x*) {
    return ArraySeq(x)
}

seqReverse(a) {
    return range(a.Length, 1, -1).map(i => a[i])
}

seqPairs(m) {
    fun() {
        e := m.__Enum(2)
        return (&p) => (e.Call(&k, &v) ? p := [k, v] : false)
    }
    return EnumSeq(fun)
}

seqGenBy(seed, unaryMapper) {
    fun(c) {
        t := seed
        c(t)
        while true {
            c(t := unaryMapper(t))
        }
    }
    return Seq(fun)
}

seqGenByTwo(seed1, seed2, binaryMapper) {
    fun(c) {
        t1 := seed1
        t2 := seed2
        c(t1)
        c(t2)
        while true {
            next := binaryMapper(t1, t2)
            c(next)
            t1 := t2
            t2 := next
        }
    }
    return Seq(fun)
}

seqReadlines(fileName, encoding?) {
    read() {
        fileObj := FileOpen(fileName, 'r', encoding?)
        call(&line) {
            if not fileObj.AtEOF {
                line := fileObj.ReadLine()
                return true
            }
            fileObj.Close()
            return false
        }
        return call
    }
    return EnumSeq(read)
}

seqSplit(s, sep, limit := -1) {
    fun(consumer) {
        n := 0
        loop parse s, sep {
            consumer(A_LoopField)
            if limit > 0 and ++n == limit {
                break
            }
        }
    }
    return Seq(fun)
}

seqRepeat(n, t) {
    fun() {
        i := 0
        return (&x) => (x := t, i++ < n)
    }
    return EnumSeq(fun)
}


class ItrSeq extends Seq {
    __New(a) {
        this._a := a
    }

    __Enum(NumberOfVars) {
        return this._a.__Enum(NumberOfVars)
    }

    consume(consumer) {
        try {
            for t in this {
                consumer(t)
            }
        } catch StopError {
        }
    }

    consumeIndexed(indexedConsumer) {
        try {
            for i, t in this {
                indexedConsumer(i, t)
            }
        } catch StopError {
        }
    }

    map(mapper) {
        fun() {
            e := this.__Enum(1)
            res(&x) {
                if not e.Call(&t) {
                    return false
                }
                x := mapper(t)
                return true
            }
            return res
        }
        return EnumSeq(fun)
    }

    mapIndexed(indexedMapper) {
        fun() {
            e := this.__Enum(2)
            res(&x) {
                if not e.Call(&i, &t) {
                    return false
                }
                x := indexedMapper(i, t)
                return true
            }
            return res
        }
        return EnumSeq(fun)
    }
}


class ArraySeq extends ItrSeq {
    toArray() {
        return this._a
    }
}


class EnumSeq extends ItrSeq {
    __New(enumFunc) {
        this._enumFunc := enumFunc
    }

    __Enum(NumberOfVars) {
        fun := this._enumFunc.Call()
        if NumberOfVars == 1 {
            return fun
        } else if NumberOfVars == 2 {
            j := 1
            return (&i, &t) => (i := j++, fun(&t))
        } else {
            throw ValueError(NumberOfVars)
        }
    }
}

range(start, end, step := 1) {
    if step > 0 {
        positive() {
            j := start
            return (&i) => (i := j, j += step, i <= end)
        }
        return EnumSeq(positive)
    } else if step < 0 {
        negative() {
            j := start
            return (&i) => (i := j, j += step, i >= end)
        }
        return EnumSeq(negative)
    } else {
        throw ValueError('zero step')
    }
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
