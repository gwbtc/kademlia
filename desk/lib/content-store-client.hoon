::  Convenience constructors for agents wrapped in content-store-agent.
::
/-  *content-store
|%
::  Build the local poke for an agent wrapped in content-store-agent.
++  poke
  |=  [our=@p dap=term command=content-store-command =wire]
  ^-  card:agent:gall
  :*  %pass  wire
      %agent  [our dap]
      %poke  %content-store-command  !>(command)
  ==
::
::  Register a callback before starting an operation.  The returned cards are
::  deliberately ordered observe-first, operation-second.  An agent that wants
::  the result in its own +on-poke names itself as the recipient.
++  start
  |=  $:  our=@p
          dap=term
          id=content-store-id
          recipient=@tas
          reply-path=path
          command=content-store-command
      ==
  ^-  (list card:agent:gall)
  :~  %:  poke
        our
        dap
        [%observe id recipient reply-path]
        /content-store/observe/(scot %uv id)
      ==
      (poke our dap command /content-store/start/(scot %uv id))
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
::  Retrieve immutable content if necessary and advertise a local provider.
++  pin
  |=  [id=content-store-id content=digest lifetime=(unit @dr)]
  ^-  content-store-command
  [%pin id content lifetime]
::  Stop retaining pin intent; existing provider records expire naturally.
++  unpin
  |=  [id=content-store-id content=digest]
  ^-  content-store-command
  [%unpin id content]
::  Drop the digest a name settled on here.  A wrapped agent that
::  rejects what a %get fetched sends this from the result's own event.
++  unname
  |=  [publisher=@p namespace=@tas name=path]
  ^-  content-store-command
  [%unname publisher namespace name]
::  Publish only by immutable digest.
++  unnamed
  ^-  publication-options
  [~ ~]
::  Also publish a mutable, publisher-scoped name.
++  with-name
  |=  [namespace=@tas name=path lifetime=(unit @dr)]
  ^-  publication-options
  [`[namespace name [%auto ~] lifetime] ~]
::  Publish a mutable name at an explicit revision for import or recovery.
++  with-name-at
  |=  [namespace=@tas name=path revision=@ud lifetime=(unit @dr)]
  ^-  publication-options
  [`[namespace name [%set revision] lifetime] ~]
::  Publish only if the local name counter has the expected revision.
++  with-name-cas
  |=  $:  namespace=@tas
          name=path
          expected=@ud
          revision=@ud
          lifetime=(unit @dr)
      ==
  ^-  publication-options
  [`[namespace name [%cas expected revision] lifetime] ~]
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
