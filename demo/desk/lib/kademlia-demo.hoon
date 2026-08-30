::  Pure deterministic-resource and bounded-chunk helpers for the demo agent.
::
/-  *content-routing, *kademlia-demo
/+  cr=content-routing
|%
::  Derive one nonzero fill octet from the resource seed.
++  fill-for
  |=  seed=@
  ^-  @ud
  =/  octet=@ud  (end 3 (shax (jam [%kademlia-demo-resource-v1 seed])))
  ?:  =(0 octet)  1
  octet
::
::  Construct an atom containing +size repetitions of one byte.  The soft
::  +fil implementation grows the atom one byte at a time and is quadratic;
::  this geometric-series form uses jetted big-integer arithmetic instead.
++  repeat-byte
  |=  [size=@ud byte=@]
  ^-  @
  ?>  (lth byte 256)
  ?:  =(0 size)  0
  (mul byte (div (dec (bex (mul 8 size))) 255))
::
::  Materialize a resource noun.
++  resource-cask
  |=  [seed=@ size=@ud mime=@t]
  ^-  (cask)
  =/  fill=@ud  (fill-for seed)
  [%kademlia-demo-resource [mime size (repeat-byte size fill)]]
::
::  Construct and commit a compact descriptor.
++  make-resource
  |=  [seed=@ size=@ud mime=@t]
  ^-  resource
  =/  fill=@ud  (fill-for seed)
  =/  content=digest  (digest-cask:cr (resource-cask seed size mime))
  [seed size mime fill content]
::
::  Generate an independently addressable chunk without materializing the
::  complete source resource.
++  chunk
  |=  [res=resource offset=@ud length=@ud]
  ^-  @
  ?>  (lte (add offset length) size.res)
  (repeat-byte length fill.res)
::
::  Validate a chunk response before it is inserted into an assembly buffer.
++  chunk-valid
  |=  $:  expected=digest
          offset=@ud
          requested=@ud
          total=@ud
          length=@ud
          payload=@
          max-total=@ud
          max-chunk=@ud
      ==
  ^-  ?
  ?&  (lte total max-total)
      (lte length requested)
      (lte length max-chunk)
      (lte (add offset length) total)
      =((met 3 payload) length)
      (digest-valid:cr expected)
  ==
::
::  Insert one validated byte chunk at its byte offset.
++  insert-chunk
  |=  [buffer=@ offset=@ud payload=@]
  ^-  @
  (add buffer (lsh [3 offset] payload))
::
::  Verify the reconstructed content cask.
++  verify-resource
  |=  [expected=digest mime=@t size=@ud data=@]
  ^-  ?
  (verify-cask:cr expected [%kademlia-demo-resource [mime size data]])
--
