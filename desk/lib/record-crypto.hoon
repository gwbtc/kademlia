::  Record signing and verification against Jael networking keys.
::
/-  *kademlia, *content-routing
/+  kad=kademlia
|%
++  sign-digest
  |=  [=bowl:gall message=digest]
  ^-  record-signature
  =/  life=@ud
    .^(@ud %j /(scot %p our.bowl)/life/(scot %da now.bowl)/(scot %p our.bowl))
  =/  secret=ring
    .^(ring %j /(scot %p our.bowl)/vein/(scot %da now.bowl)/(scot %ud life))
  =/  cub  (nol:nu:cric:crypto secret)
  [life (sigh:as:cub message)]
::
++  fake-public
  |=  ship=@p
  ^-  pass
  =/  cub  (pit:nu:cric:crypto 512 ship %b ~)
  pub:ex:cub
::
++  normalize-public
  |=  raw=*
  ^-  (unit [crypto-suite=@ud =pass])
  ?@  raw  ~
  ?.  =(~ -.raw)  ~
  =/  value=*  +.raw
  ?@  value  `[1 `pass`value]
  ?.  ?&  ?=(@ -.value)
          ?=(@ +.value)
      ==
    ~
  `[`@ud`-.value `pass`+.value]
::
::  check-record: produce ~ for a valid signature, else the failure to log.
::
++  check-record
  |=  [=bowl:gall signer=node-id message=digest signature=*]
  ^-  (unit [ship=@p life=@ud reason=term])
  =/  sig=record-signature  ;;(record-signature signature)
  =/  ship=@p  (~(node-to-ship kad [20 20 3 12 %kademlia-urbit-v1]) signer)
  =/  raw=*
    .^  *
      %j
      /(scot %p our.bowl)/puby/(scot %da now.bowl)/(scot %p ship)/(scot %ud life.sig)
    ==
  =/  public=(unit [crypto-suite=@ud =pass])  (normalize-public raw)
  =/  public=(unit [crypto-suite=@ud =pass])
    ?^  public  public
    =/  fake=?
      .^(? %j /(scot %p our.bowl)/fake/(scot %da now.bowl))
    ?.  ?&  fake
            =(1 life.sig)
        ==
      ~
    `[1 (fake-public ship)]
  ?~  public
    `[ship life.sig %no-public-key]
  ?.  ?=(?(%1 %2) crypto-suite.u.public)
    `[ship life.sig %unsupported-suite]
  =/  them  (com:nu:cric:crypto pass.u.public)
  ?.  (safe:as:them value.sig message)
    `[ship life.sig %bad-signature]
  ~
--
