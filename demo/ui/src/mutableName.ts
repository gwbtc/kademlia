export const MAX_MUTABLE_NAME_SEGMENTS = 16;
export const MAX_MUTABLE_NAME_SEGMENT_BYTES = 64;

export function mutableNameSegments(value: string): string[] {
  const segments = value
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean);

  if (segments.length === 0 || segments.length > MAX_MUTABLE_NAME_SEGMENTS) {
    throw new Error(`Mutable names must contain 1-${MAX_MUTABLE_NAME_SEGMENTS} segments.`);
  }

  const encoder = new TextEncoder();
  if (segments.some((segment) => encoder.encode(segment).byteLength > MAX_MUTABLE_NAME_SEGMENT_BYTES)) {
    throw new Error(`Mutable-name segments must be at most ${MAX_MUTABLE_NAME_SEGMENT_BYTES} bytes.`);
  }

  return segments;
}
