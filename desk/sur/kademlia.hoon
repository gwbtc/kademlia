::  Routing and lookup types for a Kademlia overlay.
::
|%
+$  node-id  @ux                      ::  restricted to 128 bits
+$  key      @ux                      ::  restricted to 128 bits
+$  contact
  $:  id=node-id                    ::  canonical identity; decodes to @p
      seen=@da
      fails=@ud
  ==
+$  contacts  (list contact)
+$  lookup-status  ?(%unasked %in-flight %succeeded %failed)
+$  lookup-candidate
  $:  id=node-id
      status=lookup-status
  ==
+$  lookup-candidates  (list lookup-candidate)
+$  roster
  $:  count=@ud
      items=contacts
  ==
+$  bucket
  $:  live=roster                   ::  most-recently seen first
      replacements=roster           ::  most-recent candidate first
  ==
+$  table  (map @ud bucket)        ::  XOR bit index -> bucket
+$  config
  $:  k=@ud                        ::  live entries per bucket
      replacement-k=@ud            ::  backup entries per bucket
      alpha=@ud                    ::  maximum simultaneous lookup requests
      rounds=@ud                   ::  number of feistel rounds
      tweak=*                      ::  feistel domain separator
  ==
+$  lookup
  $:  target=node-id
      candidates=lookup-candidates  ::  all discovered IDs, nearest first
  ==
--
