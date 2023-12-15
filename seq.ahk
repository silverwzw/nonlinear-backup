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
    return x => not test(x)
}


class Seq {
    static fold(acc, accumulator) {
        this.consume(t => acc := accumulator(acc, t))
        return acc
    }

    static reduce(des, reducer) {
        this.consume(t => reducer(des, t))
        return des
    }

    static consumeIndexed(indexedConsumer) {
        i := 1
        this.consume(t => indexedConsumer(i++, t))
        return i
    }

    static map(mapper) {
        return CallbackSeq(c => this.consume(t => c(mapper(t))))
    }

    static mapIndexed(indexedMapper) {
        fun(c) {
            i := 1
            this.consume(t => c(indexedMapper(i++, t)))
        }
        return CallbackSeq(fun)
    }

    static mapOut(mapper) {
        b := []
        this.consume(t => b.Push(mapper(t)))
        return b
    }

    static mapIndexedOut(indexedMapper) {
        b := []
        this.consumeIndexed((i, t) => b.Push(indexedMapper(i, t)))
        return b
    }

    static filter(test) {
        return CallbackSeq(c => this.consume(t => test(t) ? c(t) : 0))
    }

    static filterOut(test) {
        b := []
        this.consume(t => test(t) ? b.Push(t) : 0)
        return b
    }

    static onEach(consumer) {
        return CallbackSeq(c => this.consume(t => (consumer(t), c(t))))
    }

    static take(n) {
        return CallbackSeq(c => this.consumeIndexed((i, t) => i <= n ? c(t) : stop()))
    }

    static drop(n) {
        return this.partial(t => 0, n)
    }

    static partial(consumer, n := 1) {
        return CallbackSeq(c => this.consumeIndexed((i, t) => (i > n ? c : consumer).Call(t)))
    }

    static takeWhile(test) {
        return CallbackSeq(c => this.consume(t => test(t) ? c(t) : stop()))
    }

    static dropWhile(test) {
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
        return CallbackSeq(fun)
    }

    static chunked(n) {
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
        return CallbackSeq(fun)
    }

    static flatMap(toSeqMapper) {
        return CallbackSeq(c => this.consume(t => toSeqMapper(t).consume(c)))
    }

    static runningFold(init, accumulator) {
        fun(c) {
            acc := init
            this.consume(t => c(acc := accumulator(acc, t)))
        }
        return CallbackSeq(fun)
    }

    static append(t*) {
        this.appendAll(t)
    }

    static appendAll(a) {
        fun(c) {
            this.consume(c)
            for t in a {
                c(a)
            }
        }
        return CallbackSeq(fun)
    }

    static any(test) {
        return this.find(&_, test)
    }

    static all(test) {
        return not this.find(&_, negate(test))
    }

    static none(test) {
        return not this.find(&_, test)
    }

    static first(&res) {
        this.consume(t => (res := t, stop()))
        return IsSet(res)
    }

    static find(&res, test) {
        this.consume(t => test(t) ? (res := t, stop()) : 0)
        return IsSet(res)
    }

    static count(test?) {
        return IsSet(test) ? this.sum(t => test(t) ? 1 : 0) : this.sum(t => 1)
    }

    static sum(numMapper?) {
        res := 0
        if IsSet(numMapper) {
            this.consume(t => res += numMapper(t))
        } else {
            this.consume(t => res += t)
        }
        return res
    }

    static average(numMapper, weightMapper?) {
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

    static max(&res, comparator?) {
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

    static maxBy(&res, valMapper, &val?) {
        fun(t) {
            v := valMapper(t)
            if not IsSet(res) or val < v {
                res := t
                val := v
            }
        }
        this.consume(fun)
        return IsSet(res)
    }

    static min(&res, comparator?) {
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

    static minBy(&res, valMapper, &val?) {
        fun(t) {
            v := valMapper(t)
            if not IsSet(res) or val > v {
                res := t
                val := v
            }
        }
        this.consume(fun)
        return IsSet(res)
    }

    static distinct() {
        fun(c) {
            m := Map()
            return this.consume(t => m.Has(t) ? 0 : c(m[t] := t))
        }
        return CallbackSeq(fun)
    }

    static distinctBy(mapper) {
        fun(c) {
            m := Map()
            return this.consume(t => (k := mapper(t), m.Has(k) ? 0 : c(m[k] := t)))
        }
        return CallbackSeq(fun)
    }

    static sort(optCNR := 'C') {
        sep := '`n'
        s := Sort(this.join(sep), optCNR)
        return seqSplit(s, sep)
    }

    static sortOut(optCNR := 'C') {
        sep := '`n'
        s := Sort(this.join(sep), optCNR)
        return StrSplit(s, sep)
    }

    static sortBy(mapper, optCNR := 'C', interSep := '``') {
        sep := '`n'
        a := this.toArr()
        after := Sort(this.mapIndexed((i, t) => mapper(t) interSep i).join(sep), optCNR)
        return seqSplit(after, sep).map(t => a[Integer(StrSplit(t, interSep)[2])])
    }

    static toArr() {
        return this.reduce([], _arrayPusher)
    }

    static reverse() {
        return this.toArr().reverse()
    }

    static reverseOut() {
        return this.toArr().reverseOut()
    }

    static partition(test, &part1, &part2) {
        part1 := []
        part2 := []
        this.consume(t => (test(t) ? part1 : part2).Push(t))
    }

    static mapSub(headTest, headRestMapper) {
        head := unset
        rest := unset
        f(c) {
            g(t) {
                if headTest(t) {
                    if IsSet(head) {
                        c(headRestMapper(head, rest))
                    }
                    head := t
                    rest := []
                } else if IsSet(head) {
                    rest.Push(t)
                }
            }
            this.consume(g)
            if IsSet(head) {
                c(headRestMapper(head, rest))
            }
        }
        return CallbackSeq(f)
    }

    static toMap(keyMapper, valueMapper) {
        return this.reduce(Map(), (m, x) => m[keyMapper(x)] := valueMapper(x))
    }

    static toMapBy(keyMapper) {
        return this.reduce(Map(), (m, x) => m[keyMapper(x)] := x)
    }

    static toMapWith(valueMapper) {
        return this.reduce(Map(), (m, x) => m[x] := valueMapper(x))
    }

    static toIndexMap(keyMapper?) {
        m := Map()
        IsSet(keyMapper)
        ? this.consumeIndexed((i, t) => m[keyMapper(t)] := i)
        : this.consumeIndexed((i, t) => m[t] := i)
        return m
    }

    static toSet() {
        return this.reduce(Map(), (m, x) => m[x] := '')
    }

    static groupBy(toKey, valueMapper?) {
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

    static join(sep?, mapper?) {
        if IsSet(mapper) {
            if IsSet(sep) and sep {
                rest := false
                return this.fold('', (acc, t) => rest ? acc sep mapper(t) : (rest := true, mapper(t)))
            } else {
                return this.fold('', (acc, t) => acc mapper(t))
            }
        } else {
            if IsSet(sep) and sep {
                rest := false
                return this.fold('', (acc, t) => rest ? acc sep t : (rest := true, t))
            } else {
                return this.fold('', _strConcat)
            }
        }
    }
}

pair(k, v) {
    return [k, v]
}

seqPairs(enum2, kvMapper := pair) {
    fun() {
        e := enum2 is Enumerator ? enum2 : enum2.__Enum(2)
        return (&p) => (e.Call(&k, &v) ? p := kvMapper(k, v) : false)
    }
    return EnumSeq(fun)
}

seqRepeat(n, t) {
    fun() {
        i := 0
        return (&x) => (x := t, i++ < n)
    }
    return EnumSeq(fun)
}

seqRepeatBy(n, supplier) {
    fun() {
        i := 0
        return (&x) => (x := supplier(), i++ < n)
    }
    return EnumSeq(fun)
}

seqGenBy(seed, unaryMapper) {
    fun() {
        x := seed
        return (&t) => (x := unaryMapper(t := x), true)
    }
    return EnumSeq(fun)
}

seqGenByTwo(seed1, seed2, binaryMapper) {
    fun() {
        x1 := seed1
        x2 := seed2
        return (&t) => (x2 := binaryMapper(t := x1, x1 := x2), true)
    }
    return EnumSeq(fun)
}

seqReadlines(fileName, encoding?) {
    fun() {
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
    return EnumSeq(fun)
}

seqSplit(s, sep, limit := -1) {
    fun(consumer) {
        if limit > 0 {
            loop parse s, sep {
                consumer(A_LoopField)
                if --limit == 0 {
                    break
                }
            }
        } else {
            loop parse s, sep {
                consumer(A_LoopField)
            }
        }
    }
    return CallbackSeq(fun)
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

class CallbackSeq {
    static Prototype.Base := Seq

    __New(consumerConsumer) {
        this.consumerConsumer := consumerConsumer
    }

    consume(consumer) {
        try {
            this.consumerConsumer.Call(consumer)
        } catch StopError {
        }
    }
}

class Iterable extends Seq {
    static consume(consumer) {
        try {
            for t in this {
                consumer(t)
            }
        } catch StopError {
        }
    }

    static consumeIndexed(indexedConsumer) {
        try {
            for i, t in this {
                indexedConsumer(i, t)
            }
        } catch StopError {
        }
    }

    static map(mapper) {
        fun() {
            e := this.__Enum(1)
            g(&x) {
                if e.Call(&t) {
                    x := mapper(t)
                    return true
                }
                return false
            }
            return g
        }
        return EnumSeq(fun)
    }

    static mapIndexed(indexedMapper) {
        fun() {
            e := this.__Enum(2)
            g(&x) {
                if e.Call(&i, &t) {
                    x := indexedMapper(i, t)
                    return true
                }
                return false
            }
            return g
        }
        return EnumSeq(fun)
    }

    static filter(test) {
        fun() {
            e := this.__Enum(1)
            g(&x) {
                while e.Call(&t) {
                    if test(t) {
                        x := t
                        return true
                    }
                }
                return false
            }
            return g
        }
        return EnumSeq(fun)
    }

    static runningFold(init, accumulator) {
        fun() {
            acc := init
            e := this.__Enum(1)
            g(&x) {
                if e.Call(&t) {
                    x := acc := accumulator(acc, t)
                    return true
                }
                return false
            }
            return g
        }
        return EnumSeq(fun)
    }
}

class EnumSeq {
    static Prototype.Base := Iterable

    __New(enumFunc) {
        this.enumFunc := enumFunc
    }

    __Enum(NumberOfVars) {
        fun := this.enumFunc.Call()
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

extendClass(target, base) {
    define := Object.Prototype.DefineProp
    for prop in base.OwnProps() {
        if SubStr(prop, 1, 2) != '__' {
            define(target.Prototype, prop, base.GetOwnPropDesc(prop))
        }
    }
}
