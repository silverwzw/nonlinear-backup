_arrayPusher := (des, s) => des.Push(s)
_strConcat := (acc, s) => acc s
_void := {}

class StopError extends ValueError {
}
_stopError := StopError()

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
        return Seq(c => this.consume(t => test(t) ? c(t) : _void))
    }

    take(n) {
        return Seq(c => this.consumeIndexed((i, t) => i <= n ? c(t) : stop()))
    }

    drop(n) {
        return this.partial(t => _void, n)
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

    sum(numMapper) {
        res := 0
        this.consume(t => res += numMapper(t))
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

    toArray(mapper?) {
        return this.reduce([], IsSet(mapper) ? (des, s) => des.Push(mapper(s)) : _arrayPusher)
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

    join(sep?, mapper?) {
        if IsSet(sep) and sep != '' {
            rest := false
            if IsSet(mapper) {
                ifMapper(acc, t) {
                    if rest
                        return acc sep mapper(t)
                    else {
                        rest := true
                        return mapper(t)
                    }
                }
                return this.fold('', ifMapper)
            } else {
                nonMapper(acc, t) {
                    if rest
                        return acc sep t
                    else {
                        rest := true
                        return t
                    }
                }
                return this.fold('', nonMapper)
            }
        } else {
            return this.fold('', IsSet(mapper) ? (acc, t) => acc mapper(t) : _strConcat)
        }
    }
}

seqOf(a) {
    return ItrSeq(a)
}

seqAll(x*) {
    return ItrSeq(x)
}

seqReverse(a) {
    return range(a.Length, 1, -1).map(i => a[i])
}

seqPairs(m) {
    fun(consumer) {
        for t1, t2 in m
            consumer(Pair(t1, t2))
    }
    return Seq(fun)
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

    map(indexedMapper) {
        fun() {
            e := this.__Enum(1)
            res(&x) {
                if not e.Call(&t) {
                    return false
                }
                x := indexedMapper(t)
                return true
            }
            return res
        }
        return EnumSeq(fun)
    }

    mapIndexed(mapper) {
        fun() {
            e := this.__Enum(2)
            res(&x) {
                if not e.Call(&i, &t) {
                    return false
                }
                x := mapper(i, t)
                return true
            }
            return res
        }
        return EnumSeq(fun)
    }
}

class EnumSeq extends ItrSeq {
    __New(enumFunc) {
        this._enumFunc := enumFunc
    }

    __Enum(NumberOfVars) {
        if NumberOfVars == 1 {
            return this._enumFunc.Call()
        } else if NumberOfVars == 2 {
            fun := this._enumFunc.Call()
            j := 1
            return (&i, &t) => (b := fun.Call(&t), i := j++, b)
        } else {
            throw ValueError(NumberOfVars)
        }
    }
}

range(start, end, step := 1) {
    if step > 0 {
        positive() {
            j := start
            return (&i) => (i := j, j := i + step, i <= end)
        }
        return EnumSeq(positive)
    } else if step < 0 {
        negative() {
            j := start
            return (&i) => (i := j, j := i + step, i >= end)
        }
        return EnumSeq(negative)
    } else {
        throw ValueError('zero step')
    }
}

class Pair {
    __New(first, second) {
        this.first := first
        this.second := second
    }
}
