import std/[os, sha1]

const signature = "NPAT\x01"

proc require(condition: bool, message: string) =
  if not condition:
    raise newException(ValueError, message)

proc put64(data: var string, value: int) =
  for i in 0 ..< 8:
    data.add(char((uint64(value) shr (8 * i)) and 255))

proc take(data: string, pos: var int, count: int): string =
  require(count >= 0 and count <= data.len - pos, "Truncated patch")
  result = data[pos ..< pos + count]
  pos += count

proc get64(data: string, pos: var int): int =
  var value = 0'u64
  for i, byte in take(data, pos, 8):
    value = value or (uint64(ord(byte)) shl (8 * i))
  require(value <= uint64(high(int)), "Size exceeds platform range")
  int(value)

proc createPatch(oldData, newData: string): string =
  result = signature
  result.put64(oldData.len)
  result.put64(newData.len)
  result.add($secureHash(oldData))
  let shared = min(oldData.len, newData.len)
  var prefix, suffix: int
  while prefix < shared and oldData[prefix] == newData[prefix]:
    inc prefix
  while suffix < shared - prefix and
      oldData[oldData.len - 1 - suffix] == newData[newData.len - 1 - suffix]:
    inc suffix
  if prefix > 0:
    result.add('C')
    result.put64(0)
    result.put64(prefix)
  let middle = newData.len - prefix - suffix
  if middle > 0:
    result.add('I')
    result.put64(middle)
    result.add(newData[prefix ..< prefix + middle])
  if suffix > 0:
    result.add('C')
    result.put64(oldData.len - suffix)
    result.put64(suffix)

proc applyPatch(oldData, patch: string): string =
  var pos = 0
  require(take(patch, pos, signature.len) == signature, "Bad signature or version")
  require(get64(patch, pos) == oldData.len, "Source size mismatch")
  let targetSize = get64(patch, pos)
  require(take(patch, pos, 40) == $secureHash(oldData), "Source checksum mismatch")
  while pos < patch.len:
    let opcode = take(patch, pos, 1)[0]
    case opcode
    of 'C':
      let offset = get64(patch, pos)
      let length = get64(patch, pos)
      require(offset <= oldData.len and length <= oldData.len - offset,
        "COPY exceeds source bounds")
      require(length > 0 and length <= targetSize - result.len, "Invalid COPY length")
      result.add(oldData[offset ..< offset + length])
    of 'I':
      let length = get64(patch, pos)
      require(length > 0 and length <= targetSize - result.len, "Invalid INSERT length")
      result.add(take(patch, pos, length))
    else:
      raise newException(ValueError, "Unknown patch operation")
  require(result.len == targetSize, "Target size mismatch")

try:
  require(paramCount() == 4, "Usage: patch create OLD NEW PATCH | patch apply OLD PATCH RESTORED")
  let operation = paramStr(1)
  require(operation == "create" or operation == "apply", "Expected create or apply")
  let oldData = readFile(paramStr(2))
  let other = readFile(paramStr(3))
  let output = if operation == "create": createPatch(oldData, other)
               else: applyPatch(oldData, other)
  writeFile(paramStr(4), output)
  echo "Wrote ", output.len, " bytes to ", paramStr(4)
except CatchableError as err:
  stderr.writeLine("Error: ", err.msg)
  quit(1)
