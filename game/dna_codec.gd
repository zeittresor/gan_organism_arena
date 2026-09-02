extends RefCounted

# Fictional regulatory code: ten base-4 nucleotides encode one quantitative
# allele. This is deliberately not the real codon/amino-acid genetic code.
const BASES: String = "ACGT"
const BASE_COUNT: int = 10
const MAX_CODE: int = 1048575

static func encode(value: float) -> String:
    var code: int = int(round(clampf(value, 0.0, 1.0) * MAX_CODE))
    var sequence: String = ""
    for i in range(BASE_COUNT):
        sequence = BASES[code % 4] + sequence
        code = int(code / 4)
    return sequence

static func decode(sequence: String) -> float:
    if sequence.length() != BASE_COUNT: return -1.0
    var code: int = 0
    for base in sequence:
        var index: int = BASES.find(base)
        if index < 0: return -1.0
        code = code * 4 + index
    return float(code) / MAX_CODE

static func point_mutation(value: float, rng: RandomNumberGenerator, strength: float) -> float:
    var sequence: String = encode(value)
    var first: int = clampi(int(-log(maxf(0.0001, strength)) / log(4.0)), 0, 8)
    var position: int = rng.randi_range(first, BASE_COUNT - 1)
    var old: int = BASES.find(sequence[position])
    var replacement: String = BASES[(old + rng.randi_range(1, 3)) % 4]
    sequence = sequence.substr(0, position) + replacement + sequence.substr(position + 1)
    return decode(sequence)

static func complement(sequence: String) -> String:
    var result: String = ""
    for base in sequence:
        var index: int = BASES.find(base)
        result += "TGCA"[index] if index >= 0 else "N"
    return result
