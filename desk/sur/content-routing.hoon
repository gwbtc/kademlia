::  Content-addressed discovery types layered above Kademlia.
::
/-  *kademlia
|%
+$  digest  @uvI                       ::  sha-256 of jammed (cask)
+$  locator
  $%  [%scry spar=spar:ames]           ::  exact remote-scry address
      [%custom protocol=@tas address=*]
  ==
+$  locators  (list locator)
+$  target
  $%  [%content digest=digest]         ::  discover current providers
      $:  %direct                      ::  fetch from an explicit location
          digest=(unit digest)         ::  optional content commitment
          locations=locators
      ==
  ==
+$  pointer-body
  $:  namespace=@tas
      key=key
      publisher=node-id
      revision=@ud
      expires=(unit @da)
      target=target
  ==
+$  pointer
  [body=pointer-body signature=record-signature]
+$  pointers  (list pointer)
+$  provider-body
  $:  content=digest
      provider=node-id
      revision=@ud
      expires=@da
      locations=locators
  ==
+$  provider
  [body=provider-body signature=record-signature]
+$  providers  (list provider)
+$  record-signature
  [life=@ud value=@ux]
+$  verifier
  $-([signer=node-id message=digest signature=*] ?)
+$  pointer-selection
  $%  [%none ~]
      [%found record=pointer]
      [%conflict revision=@ud]
  ==
+$  provider-selection
  [records=providers conflicts=(set node-id)]
--
