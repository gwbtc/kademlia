::  content-store-agent: agent wrapper for publishing and fetching casks
::
::    usage: %-  agent:content-store-agent
::           %-  agent:content-discovery-agent
::           %-  agent:content-routing-agent
::           %-  agent:kademlia-agent
::           your-agent
::
::    The wrapper keeps its wires under /~/content-store and serves its
::    scries under /x/~/content-store.  It handles the %content-store-command
::    mark.  It binds published casks into the agent's remote-scry namespace
::    under /content-store, and runs its record operations through the
::    content-routing-agent and content-discovery-agent wrappers below it.
::
/-  *content-routing, cra=content-routing-agent
/-  cda=content-discovery-agent, *content-store
/+  logic=content-store-agent-logic, cr=content-routing
|%
+$  card  card:agent:gall
::
++  agent
  |=  inner=agent:gall
  =|  state=content-store-state
  =/  verbosity=content-store-verbosity  %off
  =>  |%
      ++  work
        |_  [=bowl:gall cards=(list card)]
        ++  cor     .
        ++  engine  [bowl state]
        ++  abet    [cards=(flop cards) inner=inner state=state verbosity=verbosity]
        ::
        ++  log
          |=  [level=?(%info %debug) event=*]
          ^-  ~
          ?.  ?-  verbosity
                %off    |
                %info   =(%info level)
                %debug  &
              ==
            ~
          ~&  [dap.bowl %content-store level event]
          ~
        ::
        ::  take: keep cards from below.  A result addressed to us
        ::  resumes its operation.
        ::
        ++  take
          |=  new=(list card)
          ^+  cor
          ?~  new  cor
          =/  mine=(unit cage)
            ?.  ?=([%pass * %agent ^ %poke *] i.new)  ~
            ?.  =([our.bowl dap.bowl] +<.q.i.new)  ~
            `cage.task.q.i.new
          ?~  mine
            $(new t.new, cards [i.new cards])
          ?+    p.u.mine  $(new t.new, cards [i.new cards])
              %content-routing-result
            =+  !<(notice=operation-notice:cra q.u.mine)
            ?.  ?=([%~.~ %content-store *] reply-path.notice)
              $(new t.new, cards [i.new cards])
            =.  cor
              %-  step
              %+  ~(content-result logic engine)
                t.t.reply-path.notice
              result.notice
            $(new t.new)
          ::
              %content-discovery-result
            =+  !<(notice=operation-notice:cda q.u.mine)
            ?.  ?=([%~.~ %content-store *] reply-path.notice)
              $(new t.new, cards [i.new cards])
            =.  cor
              %-  step
              %+  ~(discovery-result logic engine)
                t.t.reply-path.notice
              result.notice
            $(new t.new)
          ==
        ::
        ::  emit: namespace our cards.  A command for a layer below goes
        ::  straight to it; a result for the wrapped agent goes straight
        ::  to its +on-poke.
        ::
        ++  emit
          |=  new=(list card)
          ^+  cor
          ?~  new  cor
          ?.  ?=(%pass -.i.new)
            $(new t.new, cards [i.new cards])
          =/  down=(unit cage)
            ?.  ?=([%agent ^ %poke *] q.i.new)  ~
            ?.  =([our.bowl dap.bowl] +<.q.i.new)  ~
            =*  cage  cage.task.q.i.new
            ?+    p.cage  ~
                %content-routing-command    `cage
                %content-discovery-command  `cage
                %content-store-result
              =+  !<(notice=content-store-notice q.cage)
              ?:  ?=([%~.~ *] reply-path.notice)  ~
              `cage
            ==
          ?~  down
            $(new t.new, cards [i.new(p [%~.~ %content-store p.i.new]) cards])
          =/  out
            %-  mule  |.
            (~(on-poke inner bowl(src our.bowl)) u.down)
          ?:  ?=(%& -.out)
            =.  cor  (below p.out)
            $(new t.new)
          ::
          ::  a crash below fails the operation that sent the command
          =/  ignored  (log %debug [%lower-failed p.u.down])
          ?.  ?=([%lower @ @ @ ~] p.i.new)
            $(new t.new)
          =/  parent=(unit @uv)  (slaw %uv i.t.t.p.i.new)
          ?~  parent
            $(new t.new)
          =.  cor  (step (~(lower-failed logic engine) u.parent))
          $(new t.new)
        ::
        ++  below
          |=  out=(quip card agent:gall)
          ^+  cor
          =.  inner  +.out
          (take -.out)
        ::
        ++  step
          |=  =action:logic
          ^+  cor
          =.  state  next.action
          (emit cards.action)
        ::
        ++  init
          ^+  cor
          cor(state ~(init logic engine))
        ::
        ++  load
          |=  saved=content-store-saved-state
          ^+  cor
          cor(state state.saved, verbosity verbosity.saved)
        ::
        ++  poke-command
          |=  command=content-store-command
          ^+  cor
          ?>  =(src.bowl our.bowl)
          ?-    -.command
              %observe
            ?>  (~(valid-id logic engine) id.command)
            =/  callback=content-store-callback
              [recipient.command reply-path.command]
            =/  done=(unit content-store-result)
              (~(get by completed.state) id.command)
            ?^  done
              (emit [(~(callback-card logic engine) id.command callback u.done) ~])
            =.  callbacks.state
              (~(put by callbacks.state) id.command callback)
            cor
          ::
              %forget
            ?>  (~(valid-id logic engine) id.command)
            =.  completed.state  (~(del by completed.state) id.command)
            =.  callbacks.state  (~(del by callbacks.state) id.command)
            cor
          ::
              %set-config
            ?>  (~(valid-config logic engine) value.command)
            cor(config.state value.command)
          ::
              %set-verbosity
            cor(verbosity level.command)
          ::
              %put
            ?>  (~(valid-id logic engine) id.command)
            ?>  !(~(operation-conflict logic engine) id.command)
            =/  ignored  (log %info [%operation-start id.command %put])
            %-  step
            %:  ~(start-put logic engine)
              id.command
              value.command
              options.command
              lifetime.command
            ==
          ::
              %pin
            ?>  (~(valid-id logic engine) id.command)
            ?>  !(~(operation-conflict logic engine) id.command)
            =/  ignored  (log %info [%operation-start id.command %pin])
            %-  step
            %:  ~(start-pin logic engine)
              id.command
              content.command
              lifetime.command
            ==
          ::
              %unpin
            ?>  (~(valid-id logic engine) id.command)
            ?>  !(~(operation-conflict logic engine) id.command)
            (step (~(start-unpin logic engine) id.command content.command))
          ::
              %get
            ?>  (~(valid-id logic engine) id.command)
            ?>  !(~(operation-conflict logic engine) id.command)
            =/  ignored  (log %info [%operation-start id.command %get])
            (step (~(start-get logic engine) id.command query.command))
          ::
              %search
            ?>  (~(valid-id logic engine) id.command)
            ?>  !(~(operation-conflict logic engine) id.command)
            =/  ignored  (log %info [%operation-start id.command %search])
            (step (~(start-search logic engine) id.command topic.command))
          ==
        ::
        ++  arvo-sign
          |=  [=wire =sign-arvo]
          ^+  cor
          ?+    wire  cor
              [%scry @ ~]
            ?.  ?=([%ames %sage *] sign-arvo)  cor
            =/  id=(unit @uv)  (slaw %uv i.t.wire)
            ?~  id  cor
            (step (~(hear-sage logic engine) u.id sage.sign-arvo))
          ::
              [%scry-timeout @ @ ~]
            ?.  ?=([%behn %wake *] sign-arvo)  cor
            =/  id=(unit @uv)  (slaw %uv i.t.wire)
            =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
            ?~  id  cor
            ?~  deadline  cor
            (step (~(scry-timeout logic engine) u.id u.deadline))
          ==
        --
      --
  ^-  agent:gall
  |_  =bowl:gall
  +*  this  .
      og    ~(. inner bowl)
      up    ~(. work bowl ~)
  ::
  ++  on-init
    ^-  (quip card _this)
    =/  out  abet:init:(below:up on-init:og)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-save
    !>([[%content-store `content-store-saved-state`[state verbosity]] on-save:og])
  ::
  ++  on-load
    |=  ole=vase
    ^-  (quip card _this)
    ?.  ?=([[%content-store *] *] q.ole)
      =/  out  abet:init:(below:up (on-load:og ole))
      [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
    =+  !<([[%content-store old=content-store-saved-state] ile=vase] ole)
    =/  out  abet:(below:(load:up old) (on-load:og ile))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card _this)
    =/  out
      ?.  ?=(%content-store-command mark)
        abet:(below:up (on-poke:og mark vase))
      abet:(poke-command:up !<(content-store-command vase))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-peek
    |=  =path
    ^-  (unit (unit cage))
    ?.  ?=([%x %~.~ %content-store *] path)  (on-peek:og path)
    ?+    t.t.t.path  [~ ~]
        [%settings ~]      ``noun+!>(config.state)
        [%verbosity ~]     ``noun+!>(verbosity)
        [%publications ~]  ``noun+!>(publications.state)
        [%pins ~]          ``noun+!>(~(pinned-contents logic engine:up))
        [%names ~]         ``noun+!>(names.state)
        [%provider @ ~]
      =/  content=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  content  ~
      =/  publication=(unit local-publication)
        (~(get by publications.state) u.content)
      ?~  publication  ~
      ``noun+!>(u.publication)
    ::
        [%operation @ ~]
      =/  id=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  id  ~
      =/  done=(unit content-store-result)
        (~(get by completed.state) u.id)
      ?^  done  ``noun+!>(`content-store-view`[%complete u.done])
      =/  active=(unit content-store-operation)
        (~(get by active.state) u.id)
      ?~  active  ~
      ``noun+!>(`content-store-view`[%running u.active])
    ::
        [%content @ ~]
      =/  content=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  content  ~
      ?.  (digest-valid:cr u.content)  ~
      =/  value=(unit (cask))  (~(get by values.state) u.content)
      ?~  value  ~
      ``[p.u.value !>(q.u.value)]
    ::
    ::  the cask itself, for a reader without its mark
        [%cask @ ~]
      =/  content=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  content  ~
      =/  value=(unit (cask))  (~(get by values.state) u.content)
      ?~  value  ~
      ``noun+!>(u.value)
    ::
        [%publication @ ~]
      =/  content=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  content  ~
      =/  page=(unit published-page)  (~(get by pages.state) u.content)
      ?~  page  ~
      ``noun+!>(u.page)
    ::
    ::  the digest a publisher's name last settled on
        [%name @ @ ^]
      =/  publisher=(unit @p)  (slaw %p i.t.t.t.t.path)
      ?~  publisher  ~
      =/  content=(unit digest)
        %-  ~(get by names.state)
        [u.publisher i.t.t.t.t.t.path t.t.t.t.t.t.path]
      ?~  content  ~
      ``noun+!>(u.content)
    ==
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %content-store *] wire)
        abet:(below:up (on-agent:og wire sign))
      abet:up
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %content-store *] wire)
        abet:(below:up (on-arvo:og wire sign-arvo))
      abet:(arvo-sign:up t.t.wire sign-arvo)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-watch
    |=  =path
    ^-  (quip card _this)
    =/  out  abet:(below:up (on-watch:og path))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-leave
    |=  =path
    ^-  (quip card _this)
    =/  out  abet:(below:up (on-leave:og path))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-fail
    |=  [=term =tang]
    ^-  (quip card _this)
    =/  out  abet:(below:up (on-fail:og term tang))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  --
--
