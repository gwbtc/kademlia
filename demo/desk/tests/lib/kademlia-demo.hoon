/-  *content-routing, *kademlia-demo
/+  demo=kademlia-demo, cr=content-routing, *test
|%
++  test-repeat-byte-equivalence
  ;:  weld
    %+  expect-eq  !>((fil 3 0 0xab))
    !>((repeat-byte:demo 0 0xab))
    %+  expect-eq  !>((fil 3 1 0xab))
    !>((repeat-byte:demo 1 0xab))
    %+  expect-eq  !>((fil 3 7 0xab))
    !>((repeat-byte:demo 7 0xab))
    %+  expect-eq  !>((fil 3 64 0xff))
    !>((repeat-byte:demo 64 0xff))
  ==
::
++  test-resource-determinism
  =/  a=resource  (make-resource:demo 42 1.024 'application/octet-stream')
  =/  b=resource  (make-resource:demo 42 1.024 'application/octet-stream')
  =/  c=resource  (make-resource:demo 43 1.024 'application/octet-stream')
  ;:  weld
    %+  expect-eq  !>(a)
    !>(b)
    (expect !>(!=(content.a content.c)))
    %+  expect-eq  !>(1.024)
    !>(size.a)
  ==
::
++  test-chunk-boundaries
  =/  res=resource  (make-resource:demo 7 100 'application/octet-stream')
  =/  middle=@  (chunk:demo res 25 32)
  ;:  weld
    %+  expect-eq  !>(32)
    !>((met 3 middle))
    %+  expect-eq  !>((fil 3 32 fill.res))
    !>(middle)
    (expect-success |.((chunk:demo res 68 32)))
    (expect-fail |.((chunk:demo res 69 32)))
  ==
::
++  test-assembly-and-verification
  =/  res=resource  (make-resource:demo 99 100 'text/plain')
  =/  a=@  (chunk:demo res 0 32)
  =/  b=@  (chunk:demo res 32 32)
  =/  c=@  (chunk:demo res 64 36)
  =/  buffer=@  (insert-chunk:demo 0 0 a)
  =.  buffer  (insert-chunk:demo buffer 32 b)
  =.  buffer  (insert-chunk:demo buffer 64 c)
  ;:  weld
    %+  expect-eq  !>((fil 3 100 fill.res))
    !>(buffer)
    %+  expect-eq  !>(content.res)
    !>((digest-cask:cr [%kademlia-demo-resource ['text/plain' 100 buffer]]))
    (expect !>((verify-resource:demo content.res mime.res size.res buffer)))
    %+  expect-eq  !>(%.n)
    !>((verify-resource:demo content.res mime.res size.res (mix 1 buffer)))
  ==
::
++  test-chunk-validation
  =/  res=resource  (make-resource:demo 1 100 'text/plain')
  =/  payload=@  (chunk:demo res 32 32)
  ;:  weld
    (expect !>((chunk-valid:demo content.res 32 32 100 32 payload 1.000 64)))
    %+  expect-eq  !>(%.n)
    !>((chunk-valid:demo content.res 90 32 100 32 payload 1.000 64))
    %+  expect-eq  !>(%.n)
    !>((chunk-valid:demo content.res 32 16 100 32 payload 1.000 64))
    %+  expect-eq  !>(%.n)
    !>((chunk-valid:demo content.res 32 32 2.000 32 payload 1.000 64))
  ==
--
