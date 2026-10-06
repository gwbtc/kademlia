::  content-store-agent-logic: transitions for the content-store wrapper
::
::    Cards carry wires and reply paths relative to the wrapper; the
::    wrapper namespaces them.  Commands for the layers below are pokes to
::    our own agent, which the wrapper hands down.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/-  cd=content-discovery, cda=content-discovery-agent, *content-store
/+  kad=kademlia, cr=content-routing, discovery=content-discovery
|%
+$  card  card:agent:gall
+$  action  [cards=(list card) next=content-store-state]
+$  allocation  [@uv content-store-state]
+$  revision-allocation
  [valid=? revision=(unit @ud) next=content-store-state]
+$  page-allocation
  [page=published-page cards=(list card) next=content-store-state]
::
++  kad-cfg   `config:kad`[20 20 3 12 %kademlia-urbit-v1]
++  defaults  `content-store-config`[~s30 ~d1 8.388.608]
--
::
|_  [=bowl:gall state=content-store-state]
++  init
  ^-  content-store-state
  [defaults ~ ~ ~ ~ ~ ~ ~ ~ 0v1 0v1 ~ ~]
::
++  valid-id
  |=  id=@
  ^-  ?
  (lte (met 0 id) 64)
::
++  valid-config
  |=  cfg=content-store-config
  ^-  ?
  ?&  (gth request-timeout.cfg 0)
      (gth publication-lifetime.cfg 0)
      (gth max-content-bytes.cfg 0)
  ==
::
++  valid-options
  |=  options=publication-options
  ^-  ?
  ?.  ?~  name.options
        &
      ?&  !=(%$ namespace.u.name.options)
          (name-valid:cr name.u.name.options)
          ?~  lifetime.u.name.options
            &
          (gth u.lifetime.u.name.options 0)
      ==
    |
  ?~  topic.options  &
  ?&  (topic-valid:discovery topic.u.topic.options)
      !=(%$ format.u.topic.options)
  ==
::
++  bump-id
  |=  id=@
  ^-  @uv
  (end 6 +(id))
::
++  take-content-id
  ^-  allocation
  =/  id=@uv  (end 6 next-content.state)
  [id state(next-content (bump-id id))]
::
++  take-discovery-id
  ^-  allocation
  =/  id=@uv  (end 6 next-discovery.state)
  [id state(next-discovery (bump-id id))]
::
++  take-pointer-revision
  |=  named=(unit named-publication)
  ^-  revision-allocation
  ?~  named  [& ~ state]
  =/  key=name-key  [namespace.u.named name.u.named]
  =/  current=@ud  (~(gut by pointer-revisions.state) [key 0])
  =/  revision=(unit @ud)
    ?-  -.revision.u.named
      %auto  `+(current)
      %set   `value.revision.u.named
      %cas
        ?.  =(expected.revision.u.named current)  ~
        ?.  (gth value.revision.u.named current)  ~
        `value.revision.u.named
    ==
  ?~  revision  [| ~ state]
  =.  pointer-revisions.state
    (~(put by pointer-revisions.state) key (max current u.revision))
  [& `u.revision state]
::
++  local-poke
  |=  [app=@tas =mark payload=vase =wire]
  ^-  card
  [%pass wire %agent [our.bowl app] %poke mark payload]
::
++  content-poke
  |=  [parent=content-store-id id=@uv command=content-command]
  ^-  card
  %:  local-poke
    dap.bowl
    %content-routing-command
    !>(command)
    /lower/content/(scot %uv parent)/(scot %uv id)
  ==
::
++  discovery-poke
  |=  [parent=content-store-id id=@uv command=discovery-command:cda]
  ^-  card
  %:  local-poke
    dap.bowl
    %content-discovery-command
    !>(command)
    /lower/discovery/(scot %uv parent)/(scot %uv id)
  ==
::
::  reply: a reply path the wrapper keeps for itself
::
++  reply
  |=  [tag=path parent=content-store-id id=@uv]
  ^-  path
  :+  %~.~  %content-store
  (weld tag /(scot %uv parent)/(scot %uv id))
::
::  ask-content: observe a content-routing operation, then start it
::
++  ask-content
  |=  [tag=path parent=content-store-id id=@uv command=content-command]
  ^-  (list card)
  :~  (content-poke parent id [%observe id dap.bowl (reply tag parent id)])
      (content-poke parent id command)
  ==
::
::  ask-discovery: observe a content-discovery operation, then start it
::
++  ask-discovery
  |=  $:  tag=path
          parent=content-store-id
          id=@uv
          command=discovery-command:cda
      ==
  ^-  (list card)
  :~  (discovery-poke parent id [%observe id dap.bowl (reply tag parent id)])
      (discovery-poke parent id command)
  ==
::
++  callback-card
  |=  $:  id=content-store-id
          callback=content-store-callback
          result=content-store-result
      ==
  ^-  card
  %:  local-poke
    recipient.callback
    %content-store-result
    !>(`content-store-notice`[reply-path.callback result])
    /callback/(scot %uv id)
  ==
::
++  keen-card
  |=  [id=content-store-id =spar:ames]
  ^-  card
  [%pass /scry/(scot %uv id) %keen %.n spar]
::
++  yawn-card
  |=  [id=content-store-id =spar:ames]
  ^-  card
  [%pass /scry/(scot %uv id) %arvo %a %yawn spar]
::
++  wait-card
  |=  [id=content-store-id deadline=@da]
  ^-  card
  :*  %pass  /scry-timeout/(scot %uv id)/(scot %da deadline)
      %arvo  %b  %wait  deadline
  ==
::
++  rest-card
  |=  [id=content-store-id deadline=@da]
  ^-  card
  :*  %pass  /scry-timeout/(scot %uv id)/(scot %da deadline)
      %arvo  %b  %rest  deadline
  ==
::
::  finish: record a result, index the name a get settled, and notify
::
++  finish
  |=  [id=content-store-id result=content-store-result]
  ^-  action
  =/  named=(unit publisher-name)  (~(get by naming.state) id)
  =?  names.state  &(?=(^ named) ?=(%get -.result))
    ?>  ?=(^ named)
    (~(put by names.state) u.named content.value.result)
  =.  naming.state  (~(del by naming.state) id)
  =.  active.state  (~(del by active.state) id)
  =.  completed.state  (~(put by completed.state) id result)
  =/  callback=(unit content-store-callback)  (~(get by callbacks.state) id)
  =.  callbacks.state  (~(del by callbacks.state) id)
  ?~  callback  [~ state]
  [[(callback-card id u.callback result) ~] state]
::
++  fail
  |=  [id=content-store-id reason=content-store-failure]
  ^-  action
  (finish id [%failed reason])
::
++  publication-ok
  |=  result=operation-result:cra
  ^-  ?
  ?.  ?=(%published -.result)  |
  !=(~ accepted.value.result)
::
++  advertisement-ok
  |=  result=discovery-result:cda
  ^-  ?
  ?.  ?=(%advertised -.result)  |
  =/  records=(list publication-result:cda)  records.value.result
  ?~  records  |
  %+  levy  `(list publication-result:cda)`records
  |=(item=publication-result:cda !=(~ accepted.item))
::
++  settle-put
  |=  [id=content-store-id put=put-operation]
  ^-  action
  ?.  ?&(provider-done.put pointer-done.put topic-done.put)
    [~ state(active (~(put by active.state) id [%put put]))]
  ?^  failure.put
    (fail id u.failure.put)
  %+  finish  id
  :-  %put
  :*  content.put
      locator.put
      (need provider.put)
      pointer.put
      pointer-revision.put
      pointer-expires.put
      topic.put
  ==
::
++  first-scry
  |=  locators=locators
  ^-  (unit locator)
  |-
  ?~  locators  ~
  ?:  ?=(%scry -.i.locators)  `i.locators
  $(locators t.locators)
::
++  provider-scry
  |=  records=providers
  ^-  (unit locator)
  |-
  ?~  records  ~
  =/  record=provider  i.records
  =/  locs=locators  locations.body.record
  |-
  ?~  locs  ^$(records t.records)
  ?.  ?=(%scry -.i.locs)  $(locs t.locs)
  =/  spar=spar:ames  spar.i.locs
  ?.  =(ship.spar (~(node-to-ship kad kad-cfg) provider.body.record))
    $(locs t.locs)
  `i.locs
::
++  begin-provider-query
  |=  $:  parent=content-store-id
          content=digest
          purpose=retrieval-purpose
      ==
  ^-  action
  =^  lower=@uv  state  take-content-id
  =.  active.state
    (~(put by active.state) parent [%providers content purpose])
  :_  state
  %:  ask-content
    /retrieve/providers
    parent
    lower
    [%find-providers lower content]
  ==
::
++  begin-scry
  |=  $:  id=content-store-id
          content=digest
          source=locator
          purpose=retrieval-purpose
      ==
  ^-  action
  ?.  ?=(%scry -.source)  (fail id %unsupported-locator)
  =/  deadline=@da  (add now.bowl request-timeout.config.state)
  =.  active.state
    (~(put by active.state) id [%scry content source deadline purpose])
  :_  state
  :~  (keen-card id spar.source)
      (wait-card id deadline)
  ==
::
++  begin-pointer-query
  |=  [parent=content-store-id query=content-store-query]
  ^-  action
  ?.  ?=(%name -.query)  (fail parent %invalid)
  =^  lower=@uv  state  take-content-id
  =.  active.state  (~(put by active.state) parent [%pointer query])
  =.  naming.state
    %+  ~(put by naming.state)  parent
    [publisher.query namespace.query name.query]
  :_  state
  %:  ask-content
    /get/pointer
    parent
    lower
    :*  %find-pointer  lower  namespace.query
        (~(ship-to-node kad kad-cfg) publisher.query)
        name.query
    ==
  ==
::
::  ensure-page: bind a cask into our remote-scry namespace, once
::
++  ensure-page
  |=  [id=content-store-id content=digest value=(cask)]
  ^-  page-allocation
  =/  existing=(unit published-page)  (~(get by pages.state) content)
  ?^  existing  [u.existing ~ state]
  =/  spur=path
    /content-store/(scot %uv content)/(scot %da now.bowl)/(scot %uv id)
  =/  =locator
    [%scry our.bowl (weld /g/x/1/[dap.bowl]//1 spur)]
  =.  pages.state  (~(put by pages.state) content [spur locator])
  [[spur locator] [%pass /publish/(scot %uv id) %grow spur value]~ state]
::
++  record-publication
  |=  $:  content=digest
          =locator
          revision=@ud
          expires=@da
          pinned=?
          originated=?
          publication=publication-result:cra
      ==
  ^-  content-store-state
  =/  existing=(unit local-publication)
    (~(get by publications.state) content)
  %=    state
      publications
    %+  ~(put by publications.state)  content
    :*  locator  revision  expires
        ?|(pinned ?~(existing | pinned.u.existing))
        ?|(originated ?~(existing | originated.u.existing))
        publication
    ==
  ==
::
++  begin-pin-publication
  |=  $:  id=content-store-id
          content=digest
          fetched=?
          lifetime=(unit @dr)
      ==
  ^-  action
  =/  value=(unit (cask))  (~(get by values.state) content)
  ?~  value  (fail id %provider-not-found)
  =/  allocated=page-allocation  (ensure-page id content u.value)
  =.  state  next.allocated
  =/  expires=@da
    (add now.bowl ?~(lifetime publication-lifetime.config.state u.lifetime))
  =/  revision=@ud  +((~(gut by provider-revisions.state) [content 0]))
  =.  provider-revisions.state
    (~(put by provider-revisions.state) content revision)
  =^  lower=@uv  state  take-content-id
  =/  =locator  locator.page.allocated
  =.  active.state
    (~(put by active.state) id [%pin content locator revision expires fetched])
  :_  state
  %+  weld  cards.allocated
  %:  ask-content
    /pin/provider
    id
    lower
    [%publish-provider lower content revision expires ~[locator]]
  ==
::
++  start-put
  |=  $:  id=content-store-id
          value=(cask)
          options=publication-options
          lifetime=(unit @dr)
      ==
  ^-  action
  ?.  ?&  !=(%$ p.value)
          (valid-options options)
          ?~(lifetime & (gth u.lifetime 0))
      ==
    (fail id %invalid)
  ?.  (lte (met 3 (jam value)) max-content-bytes.config.state)
    (fail id %too-large)
  =/  pointer-allocation=revision-allocation
    (take-pointer-revision name.options)
  ?.  valid.pointer-allocation
    (fail id %revision-conflict)
  =.  state  next.pointer-allocation
  =/  pointer-revision=(unit @ud)  revision.pointer-allocation
  =/  pointer-expires=(unit @da)
    ?~  name.options  ~
    ?~  lifetime.u.name.options  ~
    `(add now.bowl u.lifetime.u.name.options)
  =/  content=digest  (digest-cask:cr value)
  =/  allocated=page-allocation  (ensure-page id content value)
  =/  page=published-page  page.allocated
  =.  state  next.allocated
  =.  values.state  (~(put by values.state) content value)
  ::
  ::  our own name settles at once, so the next put reads this one
  =?  names.state  ?=(^ name.options)
    %+  ~(put by names.state)
      [our.bowl namespace.u.name.options name.u.name.options]
    content
  =/  expires=@da
    (add now.bowl ?~(lifetime publication-lifetime.config.state u.lifetime))
  =/  provider-revision=@ud
    +((~(gut by provider-revisions.state) [content 0]))
  =.  provider-revisions.state
    (~(put by provider-revisions.state) content provider-revision)
  =/  put=put-operation
    :*  content  locator.page
        |  ~
        ?=(~ name.options)  ~  pointer-revision  pointer-expires
        provider-revision  expires
        ?=(~ topic.options)  ~
        ~
    ==
  =.  active.state  (~(put by active.state) id [%put put])
  =^  provider-id=@uv  state  take-content-id
  =/  cards=(list card)
    %+  weld  cards.allocated
    %:  ask-content
      /put/provider
      id
      provider-id
      :*  %publish-provider  provider-id  content
          provider-revision  expires  ~[locator.page]
      ==
    ==
  =^  pointer-cards=(list card)  state
    ?~  name.options  [~ state]
    =^  pointer-id=@uv  state  take-content-id
    :_  state
    %:  ask-content
      /put/pointer
      id
      pointer-id
      :*  %publish-pointer  pointer-id
          namespace.u.name.options  name.u.name.options
          (need pointer-revision)  pointer-expires
          [%content content]
      ==
    ==
  =^  topic-cards=(list card)  state
    ?~  topic.options  [~ state]
    =^  topic-id=@uv  state  take-discovery-id
    :_  state
    %:  ask-discovery
      /put/topic
      id
      topic-id
      :*  %advertise  topic-id
          topic.u.topic.options  format.u.topic.options
          content  entries.u.topic.options
          revision.u.topic.options  expires
      ==
    ==
  [:(weld cards pointer-cards topic-cards) state]
::
++  start-get
  |=  [id=content-store-id query=content-store-query]
  ^-  action
  ?-  -.query
    %content
      ?.  (digest-valid:cr digest.query)  (fail id %invalid)
      =/  local=(unit (cask))  (~(get by values.state) digest.query)
      ?~  local
        (begin-provider-query id digest.query [%get ~])
      =/  page=(unit published-page)  (~(get by pages.state) digest.query)
      %+  finish  id
      [%get digest.query u.local ?~(page ~ `locator.u.page)]
    %name
      ?.  ?&  (lte (met 0 publisher.query) 128)
              !=(%$ namespace.query)
              (name-valid:cr name.query)
          ==
        (fail id %invalid)
      (begin-pointer-query id query)
    ::
    ::  a caller that knows where the content lives skips the
    ::  provider query
    %direct
      ?.  (digest-valid:cr digest.query)  (fail id %invalid)
      =/  local=(unit (cask))  (~(get by values.state) digest.query)
      ?~  local
        (begin-scry id digest.query source.query [%get ~])
      (finish id [%get digest.query u.local `source.query])
  ==
::
++  start-pin
  |=  [id=content-store-id content=digest lifetime=(unit @dr)]
  ^-  action
  ?.  ?&  (digest-valid:cr content)
          ?~(lifetime & (gth u.lifetime 0))
      ==
    (fail id %invalid)
  ?.  (~(has by values.state) content)
    (begin-provider-query id content [%pin lifetime])
  (begin-pin-publication id content | lifetime)
::
++  start-unpin
  |=  [id=content-store-id content=digest]
  ^-  action
  ?.  (digest-valid:cr content)  (fail id %invalid)
  =/  existing=(unit local-publication)
    (~(get by publications.state) content)
  =?  publications.state  ?=(^ existing)
    (~(put by publications.state) content u.existing(pinned |))
  (finish id [%unpin content])
::
++  start-search
  |=  [id=content-store-id topic=topic-path:cd]
  ^-  action
  ?.  (topic-valid:discovery topic)  (fail id %invalid)
  =^  lower=@uv  state  take-discovery-id
  =.  active.state  (~(put by active.state) id [%search topic])
  :_  state
  (ask-discovery /search id lower [%browse lower topic])
::
::  evict: forget a cached cask, unless we publish it ourselves
::
++  evict
  |=  content=digest
  ^-  content-store-state
  ?:  (~(has by pages.state) content)  state
  state(values (~(del by values.state) content))
::
++  operation-conflict
  |=  id=content-store-id
  ^-  ?
  ?|  (~(has by active.state) id)
      (~(has by completed.state) id)
  ==
::
++  pinned-contents
  ^-  (set digest)
  %-  ~(rep by publications.state)
  |=  [[content=digest status=local-publication] out=(set digest)]
  ?:(pinned.status (~(put in out) content) out)
::
::  ids: parse the parent and lower operation ids closing a reply path
::
++  ids
  |=  [parent=@ta lower=@ta]
  ^-  (unit [parent=@uv lower=@uv])
  =/  up=(unit @uv)  (slaw %uv parent)
  =/  down=(unit @uv)  (slaw %uv lower)
  ?~  up  ~
  ?~  down  ~
  `[u.up u.down]
::
::  content-result: resume an operation from a content-routing result.
::  the path is the reply path below /~/content-store.
::
++  content-result
  |=  [=path result=operation-result:cra]
  ^-  action
  ?.  ?=([@ @ @ @ ~] path)  [~ state]
  =/  ids  (ids i.t.t.path i.t.t.t.path)
  ?~  ids  [~ state]
  =*  parent  parent.u.ids
  =/  forget=card  (content-poke parent lower.u.ids [%forget lower.u.ids])
  =/  op=(unit content-store-operation)  (~(get by active.state) parent)
  ?~  op  [[forget ~] state]
  =;  =action
    [[forget cards.action] next.action]
  ?+    [i.path i.t.path]  [~ state]
      [%put %provider]
    ?.  ?=(%put -.u.op)  [~ state]
    =/  put=put-operation  value.u.op
    =.  provider-done.put  &
    =?  provider.put  ?=(%published -.result)
      `value.result
    =.  failure.put
      ?^  failure.put  failure.put
      ?.  ?=(%published -.result)  `%dependency-failed
      ?.  (publication-ok result)  `%provider-publication-failed
      ~
    =?  state  ?&(?=(%published -.result) (publication-ok result))
      ?>  ?=(%published -.result)
      %:  record-publication
        content.put  locator.put
        provider-revision.put  provider-expires.put
        |  &  value.result
      ==
    (settle-put parent put)
  ::
      [%put %pointer]
    ?.  ?=(%put -.u.op)  [~ state]
    =/  put=put-operation  value.u.op
    =.  pointer-done.put  &
    =?  pointer.put  ?=(%published -.result)
      `value.result
    =.  failure.put
      ?^  failure.put  failure.put
      ?.  ?=(%published -.result)  `%dependency-failed
      ?.  (publication-ok result)  `%pointer-publication-failed
      ~
    (settle-put parent put)
  ::
      [%get %pointer]
    ?.  ?=(%pointer -.u.op)  [~ state]
    ?.  ?=(%pointer -.result)  (fail parent %dependency-failed)
    =/  selection=pointer-selection  selection.value.result
    ?-    -.selection
        %none      (fail parent %pointer-not-found)
        %conflict  (fail parent %pointer-conflict)
        %found
      =/  =target  target.body.record.selection
      ?-    -.target
          %content  (start-get parent [%content digest.target])
          %direct
        ?~  digest.target  (fail parent %unverifiable-direct)
        =/  source=(unit locator)  (first-scry locations.target)
        ?~  source  (fail parent %unsupported-locator)
        (begin-scry parent u.digest.target u.source [%get ~])
      ==
    ==
  ::
      [%retrieve %providers]
    ?.  ?=(%providers -.u.op)  [~ state]
    ?.  ?=(%providers -.result)  (fail parent %dependency-failed)
    =/  records=providers  records.selection.value.result
    ?~  records  (fail parent %provider-not-found)
    =/  source=(unit locator)  (provider-scry records)
    ?~  source  (fail parent %unsupported-locator)
    (begin-scry parent content.value.u.op u.source purpose.value.u.op)
  ::
      [%pin %provider]
    ?.  ?=(%pin -.u.op)  [~ state]
    =/  pin=pin-operation  value.u.op
    ?.  ?=(%published -.result)  (fail parent %dependency-failed)
    ?.  (publication-ok result)  (fail parent %provider-publication-failed)
    =.  state
      %:  record-publication
        content.pin  locator.pin  revision.pin  expires.pin
        &  |  value.result
      ==
    %+  finish  parent
    :-  %pin
    :*  content.pin  locator.pin  revision.pin  expires.pin
        value.result  fetched.pin
    ==
  ==
::
::  discovery-result: resume an operation from a content-discovery
::  result.  the path is the reply path below /~/content-store.
::
++  discovery-result
  |=  [=path result=discovery-result:cda]
  ^-  action
  =/  ids
    ?+  path  ~
      [%put %topic @ @ ~]  (ids i.t.t.path i.t.t.t.path)
      [%search @ @ ~]      (ids i.t.path i.t.t.path)
    ==
  ?~  ids  [~ state]
  =*  parent  parent.u.ids
  =/  forget=card  (discovery-poke parent lower.u.ids [%forget lower.u.ids])
  =/  op=(unit content-store-operation)  (~(get by active.state) parent)
  ?~  op  [[forget ~] state]
  =;  =action
    [[forget cards.action] next.action]
  ?:  ?=(%search -.u.op)
    ?.  ?=([%search *] path)  [~ state]
    ?.  ?=(%topic -.result)  (fail parent %dependency-failed)
    (finish parent [%search value.result])
  ?.  ?=(%put -.u.op)  [~ state]
  ?.  ?=([%put *] path)  [~ state]
  =/  put=put-operation  value.u.op
  =.  topic-done.put  &
  =?  topic.put  ?=(%advertised -.result)
    `value.result
  =.  failure.put
    ?^  failure.put  failure.put
    ?.  ?=(%advertised -.result)  `%dependency-failed
    ?.  (advertisement-ok result)  `%topic-publication-failed
    ~
  (settle-put parent put)
::
::  lower-failed: a command to a layer below crashed
::
++  lower-failed
  |=  parent=content-store-id
  ^-  action
  ?.  (~(has by active.state) parent)  [~ state]
  (fail parent %dependency-failed)
::
::  hear-sage: take the answer to a remote scry
::
++  hear-sage
  |=  [id=content-store-id =sage:mess:ames]
  ^-  action
  =/  op=(unit content-store-operation)  (~(get by active.state) id)
  ?~  op  [~ state]
  ?.  ?=(%scry -.u.op)  [~ state]
  =/  scry=scry-operation  value.u.op
  =;  =action
    :_  next.action
    :*  (rest-card id deadline.scry)
        (yawn-card id p.sage)
        cards.action
    ==
  ?~  q.sage  (fail id %remote-scry-empty)
  =/  value=(cask)  q.sage
  ?.  (lte (met 3 (jam value)) max-content-bytes.config.state)
    (fail id %remote-scry-too-large)
  ?.  (verify-cask:cr content.scry value)
    (fail id %digest-mismatch)
  =.  values.state  (~(put by values.state) content.scry value)
  ?-  -.purpose.scry
    %get  (finish id [%get content.scry value `source.scry])
    %pin  (begin-pin-publication id content.scry & lifetime.purpose.scry)
  ==
::
::  scry-timeout: give up on a remote scry at its deadline
::
++  scry-timeout
  |=  [id=content-store-id deadline=@da]
  ^-  action
  =/  op=(unit content-store-operation)  (~(get by active.state) id)
  ?~  op  [~ state]
  ?.  ?=(%scry -.u.op)  [~ state]
  ?.  =(deadline.value.u.op deadline)  [~ state]
  =/  source=locator  source.value.u.op
  ?.  ?=(%scry -.source)  [~ state]
  =/  failed=action  (fail id %request-timeout)
  [[(yawn-card id spar.source) cards.failed] next.failed]
--
