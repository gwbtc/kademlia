::  Feistel PRP, vendored from https://github.com/urbit/feistel-hoon
::
|_  $:  size=[=bloq =step]
        half=[=bloq =step]
        half-bytes=@ud
        rounds=@
        tweak=*
    ==
++  abed
  |=  [=bite rounds=@ tweak=*]
  =/  size=[=bloq =step]  ?^(bite bite [bite *step])
  =/  bits=@ud  (mul (pow 2 bloq.size) step.size)
  ?:  (gth 2 bits)
    ~_('feistel: minimum block size 2 bits' !!)
  ?:  (lth 512 bits)
    ~_('feistel: maximum block size 512 bits' !!)
  ?.  =(0 (mod bits 2))
    ~_('feistel: block size must be even number of bits' !!)
  =/  half=[=bloq =step]
    ?:  =(0 bloq.size)
      [bloq.size (div step.size 2)]
    [(dec bloq.size) step.size]
  =/  half-bytes=@ud
    =/  d=(pair @ @)
      (dvr (mul (pow 2 bloq.half) step.half) 8)
    ?:(=(0 q.d) p.d +(p.d))
  %=  ..abed
    size        size
    half        half
    half-bytes  half-bytes
    rounds      rounds
    tweak       tweak
  ==
++  en
  |=  x=@
  ?.  (fits x)
    ~_('feistel: block larger than block size' !!)
  =/  [l=@ r=@]  (split x)
  =|  i=@ud
  |-  ^-  @
  ?:  =(i rounds)  (join l r)
  $(i +(i), l r, r (mix l (f i r)))
++  de
  |=  x=@
  ?.  (fits x)
    ~_('feistel: block larger than block size' !!)
  =/  [l=@ r=@]  (split x)
  =/  i=@ud  rounds
  |-  ^-  @
  ?:  =(i 0)  (join l r)
  =/  j  (dec i)
  $(i j, l (mix r (f j l)), r l)
++  split
  |=  x=@
  ^-  [l=@ r=@]
  :-  (cut bloq.half [step.half step.half] x)
  (end half x)
++  join
  |=  [l=@ r=@]
  (rep half r l ~)
++  f
  |=  [rnd=@ud r=@]
  (end half (shay half-bytes (jam [r rnd tweak])))
++  fits
  |=  x=@
  (lte (met bloq.size x) step.size)
--
