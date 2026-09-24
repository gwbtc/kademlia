::  Typed expectations checked by the content-store Aqua observer.
::
/-  cd=content-discovery, *content-store
|%
+$  content-store-expectation
  $%  $:  %put
          content=digest
          min-accepted=@ud
          pointer=?
          topic=?
      ==
      [%get content=digest value=(cask)]
      $:  %search
          topic=topic-path:cd
          catalogs=@ud
          children=(list @tas)
      ==
  ==
+$  content-store-observer-command
  $:  %start
      id=content-store-id
      expected=content-store-expectation
      command=content-store-command
  ==
--
