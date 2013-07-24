#lang scribble/manual
@(require (for-label racket/base racket/generic))

@title[#:tag "struct-generics"]{Generic Interfaces}
@; @author[@author+email["Eli Barzilay" "eli@racket-lang.org"]
@;         @author+email["Jay McCarthy" "jay@racket-lang.org"]
@;         @author+email["Vincent St-Amour" "stamourv@racket-lang.org"]
@;         @author+email["Asumu Takikawa" "asumu@racket-lang.org"]]

@defmodule[racket/generic]


A @deftech{generic interface} allows per-type methods to be
associated with generic functions. Generic functions are defined
using a @racket[define-generics] form. Method implementations for
a structure type are defined using the @racket[#:methods] keyword
(see @secref["define-struct"]).

@defform/subs[(define-generics id
                generics-opt ...
                [method-id . kw-formals*] ...
                generics-opt ...)
              ([generics-opt
                (code:line #:fast-defaults ([fast-pred? fast-impl ...] ...))
                (code:line #:defaults ([default-pred? default-impl ...] ...))
                (code:line #:fallbacks [fallback-impl ...])
                (code:line #:defined-predicate defined-pred-id)
                (code:line #:defined-table defined-table-id)
                (code:line #:derive-property prop-expr prop-value-expr)]
               [kw-formals* (arg* ...)
                            (arg* ...+ . rest-id)
                            rest-id]
               [arg* arg-id
                     [arg-id]
                     (code:line keyword arg-id)
                     (code:line keyword [arg-id])])]{

Defines the following names, plus any specified by keyword options.

@itemlist[

 @item{@racketidfont{gen:}@racket[id] as a transformer binding for
       the static information about a new generic interface;}

 @item{@racket[id]@racketidfont{?} as a predicate identifying
       instances of structure types that implement this generic group; and}

 @item{each @racket[method-id] as a generic procedure that calls the
       corresponding method on values where
       @racket[id]@racketidfont{?} is true.
       Each @racket[method-id]'s @racket[kw-formals*] must include a required
       by-position argument that is @racket[free-identifier=?] to
       @racket[id]. That argument is used in the generic definition to
       locate the specialization.}

 @item{@racket[id]@racketidfont{/c} as a contract combinator that
       recognizes instances of structure types which implement the
       @racketidfont{gen:}@racket[id] generic interface. The combinator
       takes pairs of @racket[method-id]s and contracts. The contracts
       will be applied to each of the corresponding method implementations.
       The @racket[id]@racketidfont{/c} combinator is intended to be used to
       contract the range of a constructor procedure for a struct type that
       implements the generic interface.}

]

The @racket[#:defaults] option may be provided at most once.
When it is provided, each generic function
uses @racket[default-pred?]s to dispatch to the given default implementations,
@racket[default-impl]s, if dispatching to the generic method table fails.
The syntax of the @racket[default-impl]s is the same as the methods
provided for the @racket[#:methods] keyword for @racket[struct].

The @racket[#:fast-defaults] option may be provided at most once.
It works the same as @racket[#:defaults], except the @racket[fast-pred?]s are
checked before dispatching to the generic method table.  This option is
intended to provide a fast path for dispatching to built-in datatypes, such as
lists and vectors, that do not overlap with structures implementing
@racketidfont{gen:}@racket[id].

The @racket[#:fallbacks] option may be provided at most once.
When it is provided, the @racket[fallback-impl]s define method implementations
that are used for any instance of the generic interface that does not supply a
specific implementation.  The syntax of the @racket[fallback-impl]s is the same
as the methods provided for the @racket[#:methods] keyword for @racket[struct].

The @racket[#:defined-predicate] option may be provided at most once.
When it is provided, @racket[defined-pred-id] is defined as a
procedure that reports whether a specific instance of the generic interface
implements a given set of methods.
Specifically, @racket[(defined-pred-id v 'name ...)] produces @racket[#t] if
@racket[v] has implementations for each method @racket[name], not counting
@racket[#:fallbacks] implementations, and produces @racket[#f] otherwise.
This procedure is intended for use by
higher-level APIs to adapt their behavior depending on method
availability.

The @racket[#:defined-table] option may be provided at most once.
When it is provided, @racket[defined-table-id] is defined as a
procedure that takes an instance of the generic interface and returns an
immutable @tech{hash table} that maps symbols corresponding to method
names to booleans representing whether or not that method is
implemented by the instance.  This option is deprecated; use
@racket[#:defined-predicate] instead.

The @racket[#:derive-property] option may be provided any number of times.
Each time it is provided, it specifies a @tech{structure type property} via
@racket[prop-expr] and a value for the property via @racket[prop-value-expr].
All structures implementing the generic interface via @racket[#:methods]
automatically implement this structure type property using the provided values.
When @racket[prop-value-expr] is executed, each @racket[method-id] is bound to
its specific implementation for the @tech{structure type}.

}

@defform[(define/generic local-id method-id)
         #:contracts
         ([local-id identifier?]
          [method-id identifier?])]{

When used inside the method definitions associated with the
@racket[#:methods] keyword, binds @racket[local-id] to the generic for
@racket[method-id]. This form is useful for method specializations to
use generic methods (as opposed to the local specialization) on other
values.

Using the @racket[define/generic] form outside a @racket[#:methods]
specification in @racket[struct] (or @racket[define-struct]) is an
syntax error.}


@; Examples
@(require scribble/eval)
@(define (new-evaluator)
   (let* ([e (make-base-eval)])
     (e '(require (for-syntax racket/base)
                  racket/contract
                  racket/generic))
     e))

@(define evaluator (new-evaluator))

@examples[#:eval evaluator
(define-generics printable
  (gen-print printable [port])
  (gen-port-print port printable)
  (gen-print* printable [port] #:width width #:height [height]))

(define-struct num (v)
  #:methods gen:printable
  [(define/generic super-print gen-print)
   (define (gen-print n [port (current-output-port)])
     (fprintf port "Num: ~a" (num-v n)))
   (define (gen-port-print port n)
     (super-print n port))
   (define (gen-print* n [port (current-output-port)]
                       #:width w #:height [h 0])
     (fprintf port "Num (~ax~a): ~a" w h (num-v n)))])

(define-struct bool (v)
  #:methods gen:printable
  [(define/generic super-print gen-print)
   (define (gen-print b [port (current-output-port)])
     (fprintf port "Bool: ~a"
              (if (bool-v b) "Yes" "No")))
   (define (gen-port-print port b)
     (super-print b port))
   (define (gen-print* b [port (current-output-port)]
                       #:width w #:height [h 0])
     (fprintf port "Bool (~ax~a): ~a" w h
              (if (bool-v b) "Yes" "No")))])

(define x (make-num 10))
(gen-print x)
(gen-port-print (current-output-port) x)
(gen-print* x #:width 100 #:height 90)

(define y (make-bool #t))
(gen-print y)
(gen-port-print (current-output-port) y)
(gen-print* y #:width 100 #:height 90)

(define/contract make-num-contracted
  (-> number?
      (printable/c
        [gen-print (->* (printable?) (output-port?) void?)]
        [gen-port-print (-> output-port? printable? void?)]
        [gen-print* (->* (printable? #:width exact-nonnegative-integer?)
                         (output-port? #:height exact-nonnegative-integer?)
                         void?)]))
   make-num)

(define z (make-num-contracted 10))
(gen-print* z #:width "not a number" #:height 5)
]

@close-eval[evaluator]
