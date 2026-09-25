::  Convenience constructors for applications using %content-store.
::
/-  *content-store
|%
::  Build the local Gall poke used for any content-store command.
++  poke
  |=  [our=@p command=content-store-command =wire]
  ^-  card:agent:gall
  :*  %pass  wire
      %agent  [our %content-store]
      %poke  %content-store-command  !>(command)
  ==
::
::  Register a callback before starting an operation.  The returned cards are
::  deliberately ordered observe-first, operation-second.
++  start
  |=  $:  our=@p
          id=content-store-id
          recipient=@tas
          reply-path=path
          command=content-store-command
      ==
  ^-  (list card:agent:gall)
  :~  (poke our [%observe id recipient reply-path] /content-store/observe/(scot %uv id))
      (poke our command /content-store/start/(scot %uv id))
  ==
::
++  put
  |=  $:  id=content-store-id
          value=(cask)
          options=publication-options
          lifetime=(unit @dr)
      ==
  ^-  content-store-command
  [%put id value options lifetime]
::  Publish only by immutable digest.
++  unnamed
  ^-  publication-options
  [~ ~]
::  Also publish a mutable, publisher-scoped name.
++  with-name
  |=  [namespace=@tas name=path revision=@ud]
  ^-  publication-options
  [`[namespace name revision] ~]
::  Also advertise the value as a catalog at a topic.
++  with-topic
  |=  [topic=topic-path:cd format=@tas entries=@ud revision=@ud]
  ^-  publication-options
  [~ `[topic format entries revision]]
::  Publish both a mutable name and a topic advertisement.
++  with-name-and-topic
  |=  [name=named-publication topic=topic-publication]
  ^-  publication-options
  [`name `topic]
::
++  get-content
  |=  [id=content-store-id content=digest]
  ^-  content-store-command
  [%get id [%content content]]
::
++  get-name
  |=  [id=content-store-id publisher=@p namespace=@tas name=path]
  ^-  content-store-command
  [%get id [%name publisher namespace name]]
::
++  search
  |=  [id=content-store-id topic=topic-path:cd]
  ^-  content-store-command
  [%search id topic]
--
