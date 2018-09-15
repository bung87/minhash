# minhash
# Copyright zhoupeng
# Nim implementation of minhash algoritim
# port from https://github.com/mattilyra/LSH/blob/3db37cf07eefa3276e7409b12e73f30f596236ae/lsh/cMinhash.pyx
import random
import sets
import sequtils
import minhash/murmur3
import typetraits

export sets

const 
    UINT64_MAX = 18446744073709551615'u64
    UINT32_MAX = 4294967295'u32
    defaultRandMax:int32 = 1000000

type 
    MinHasher*[T] = object
        char_ngram:int
        seeds:seq[uint32]

iterator slide(content:string, width=4) : string {.closure.} =
    let 
        maxLen = max(content.len - width + 1, 1)
    var pos:int
    for i in 0..<maxLen:
        pos = i + width
        yield content[i..<pos]

proc minhash64*(str:string, seeds:openArray[uint32],char_ngram:int) : auto {.noInit.} =
    let strlen = str.len
    let num_seeds = seeds.len
    var 
        hashes:array[2,uint64]
        ngrams:string
        slider = slide
        s:int
    result = newSeq[UINT64_MAX](num_seeds)
    while not finished(slider):
        ngrams = slider(str,char_ngram)
        MurmurHash3_x64_128(ngrams, char_ngram, seeds[s], hashes)
        if  hashes[0] < UINT64_MAX:
            result[s] = hashes[0]
        inc s

proc minhash32*(str: string, seeds:openArray[uint32],char_ngram:int) : auto {.noInit.}=
    let strlen = str.len
    let num_seeds = seeds.len
    var 
        hashes:array[2,uint32]
        ngrams:string
        slider = slide
        s:int
    result = newSeq[UINT32_MAX](num_seeds)
    while not finished(slider):
        ngrams = slider(str,char_ngram)
        MurmurHash3_x86_32(ngrams, char_ngram, seeds[s], hashes)
        if hashes[0] < UINT32_MAX:
            result[s] = hashes[0]
        inc s
    
proc fingerprint*[T](self:MinHasher[T], text:string): seq[T] =
    when type(T) is uint64:
        result = minhash_64(text, self.seeds, self.char_ngram)
    elif type(T) is uint32:
        result = minhash32(text, self.seeds, self.char_ngram)

proc jaccard*[T](self:MinHasher[T], doc1, doc2:string):float=
    let 
        f_a = toSet(self.fingerprint(doc1))
        f_b = toSet(self.fingerprint(doc2))
    return len( f_a.intersection( f_b)) / len( f_a.union( f_b))    
    
proc initMinHasher*[T](seeds:seq[SomeInteger], char_ngram=8,random_state=0):MinHasher[T]=
    result.char_ngram = char_ngram
    result.seeds = seeds

proc initMinHasher*[T](seeds:int, char_ngram=8,random_state=0):MinHasher[T]=
    result.char_ngram = char_ngram
    var sed = newSeq[uint32](seeds)
    result.seeds = map(sed,proc(x:uint32):uint32 = cast[uint32](rand(defaultRandMax)))

when isMainModule:
    let hasher =  initMinHasher[uint64](100,3)
    assert hasher.jaccard("This is a doc", "This is a doc") == 1

    let high_j = hasher.jaccard("This is a doc", "That is a doc")
    let low_j = hasher.jaccard("This is a doc", "Cats in a tree")
    assert 0 <= low_j 
    assert low_j < high_j 
    assert high_j <= 1
