(use-modules (srfi srfi-64))

(define (my-simple-runner)
  (let* ((runner (test-runner-null))
         (num-passed 0)
         (num-failed 0))
    (test-runner-on-test-end! runner
      (lambda (runner)
        (case (test-result-kind runner)
          ((pass xpass) (set! num-passed (+ num-passed 1)))
          ((fail xfail)
           (begin
             (let
                 ((rez (test-result-alist runner)))
               (format #t
                       "~a::~a\n Expected Value: ~a | Actual Value: ~a\n Error: ~a\n Form: ~a\n"
                       (assoc-ref rez 'source-file)
                       (assoc-ref rez 'source-line)
                       (assoc-ref rez 'expected-value)
                       (assoc-ref rez 'actual-value)
                       (assoc-ref rez 'actual-error)
                       (assoc-ref rez 'source-form))
               (set! num-failed (+ num-failed 1)))))
          (else
           (format #t "something happened here\n")
           ))))
    (test-runner-on-final! runner
      (lambda (runner)
        (format #t "Passed: ~d || Failed: ~d.~%"
                num-passed num-failed)))
    runner))

(test-runner-factory
 (lambda () (my-simple-runner)))

                                        ; Standard Evaluator Tests
(define-syntax test-eval
  (syntax-rules (=> test-environment test-equal)
    ((test-eval expr =>)
     (syntax-error "no expect statement"))
    ((test-eval expr => expect)
     (test-eval expr expect))
    ((test-eval expr expect)
     (test-eqv expect (test-evaluator 'expr test-environment)))))

(test-begin "tests")
(test-begin "evaluator")
(test-begin "basic")
;; initialize
(define test-environment (setup-environment))
(define test-evaluator zeval)

;; tests
(test-eval (or 1 2)                     => 1)
(test-eval (and 1 2)                    => 2)
(test-eval (begin 1 2)                  => 2)
(test-eval ((lambda (a b) (+ a b)) 3 4) => 7)
(test-eval (let ((a 1) (b 2)) a)        => 1)
(test-eval (let* ((a 1) (b 2) (c a)) c) => 1)

(test-eval
 (let fib-iter ((a 1) (b 0) (count 4))
   (if (= count 0) b
       (fib-iter (+ a b) a (- count 1))))
 => 3)

(test-eval
 (letrec ((sum (lambda (n) (if (= n 1) 1
                               (+ n (sum (- n 1)))))))
   (sum 2))
 => 3)

(test-eval
 (begin
   (define a 1)
   (define b 2)
   (set! a 3)
   (+ a b))
 => 5)

(test-eval
 (cond
  ((= 1 2) 0)
  ((= (+ 1 1) 3) 0)
  (else 1))
 => 1)

(test-eval
 (cond
  ((= 0 1) 0)
  ((= (+ 1 1) 2) 1)
  (else 0))
 => 1)

(test-eval
 (begin
   (define test (lambda (a) a))
   (test 1))
 => 1)

(test-eval (unless true 1 0) => 0)
(test-eval (unless false 1 0) => 1)

;; cleanup
(set! test-environment '())
(test-end "basic")
(test-begin "analyzer")

;; initialize
(define test-environment (setup-environment))
(define test-evaluator aeval)

;; analyzer tests
(test-eval (let ((a 1)) a)              => 1)
(test-eval (begin 1 2)                  => 2)
(test-eval ((lambda (a b) (+ a b)) 3 4) => 7)
(test-eval (let ((a 1) (b 2)) a)        => 1)

(test-eval
 (let fib-iter ((a 1) (b 0) (count 4))
   (if (= count 0) b
       (fib-iter (+ a b) a (- count 1))))
 => 3)

(test-eval
 (begin
   (define a 1)
   (define b 2)
   (set! a 3)
   (+ a b))
 => 5)

(test-eval
 (cond
  ((= 1 2) 0)
  ((= (+ 1 1) 3) 0)
  (else 1))
 => 1)

(test-eval
 (cond
  ((= 0 1) 0)
  ((= (+ 1 1) 2) 1)
  (else 0))
 => 1)

(test-eval
 (begin
   (define test (lambda (a) a))
   (test 1))
 => 1)

(test-eval (unless true 1 0) => 0)
(test-eval (unless false 1 0) => 1)

(test-end "analyzer")
(test-begin "lazy evaluator")

;; initialize
(define test-environment (setup-environment))
(define test-evaluator leval)

;; ;; ;; analyzer tests
;; (test-eval 1 => 1)
;; (test-eval (define definet 1) => 'ok)
;; (test-eval definet => 1)
;; (test-eval (if (> 5 10) 1) => #f)
;; (test-eval (if (< 5 10) 1) => 1)
;; (test-eval (if (= 1 2) true
;;                false) => #f)
;; (test-eval
;;  (define (try a b) (if (= a 0) 1 b))
;;  => 'ok)

;; (test-eval (try 0 (/ 1 0)) => 1)

;; (test-eval
;;  (cond
;;   ((= 1 2) 0)
;;   ((= (+ 1 1) 3) 0)
;;   (else 1))
;;  => 1)

(test-end "lazy evaluator")

(test-begin "amb evaluator")
(define test-environment (setup-environment))
(amb/execute-infuse-expressions test-environment)

(define (amb/test-amb expr)
  (ambeval expr test-environment
           ;; success
           (λ (value next-alternative)
             (cons value (next-alternative)))
           ;; failure
           (λ ()
             ;; no more values
             '())))

(define (amb/test-evaluator expr)
  (ambeval expr test-environment
           (λ (value _next-alternative) value)
           (λ () (error "no values"))))

(define-syntax test-amb
  (syntax-rules (=> test-environment test-equal)
    ((test-eval expr =>)
     (syntax-error "no expect statement"))
    ((test-eval expr => expect)
     (test-assert
         (equal?
          (amb/test-evaluator 'expr)
          expect)))
    ((test-eval expr expect)
     (test-eqv expect (amb/test-evaluator 'expr)))
    ((test-eval expr &~> expect)
     (test-assert
         (equal?
          (amb/test-amb 'expr)
          expect)))))


(test-amb (if (< 1 2) true false) => #t)
(test-amb (amb 1 2 3) &~> '(1 2 3))

(test-begin "sentence puzzles")
;; these are test cases from sicp proper
(test-amb (parse '(the cat eats))
          => '(sentence (simple-noun-phrase (article the) (noun cat)) (verb eats)))

(test-amb (parse '(the student with the cat sleeps in the class))
          => '(sentence
               (noun-phrase
                (simple-noun-phrase (article the) (noun student))
                (prep-phrase
                 (prep with)
                 (simple-noun-phrase
                  (article the)
                  (noun cat))))
               (verb-phrase
                (verb sleeps)
                (prep-phrase
                 (prep in)
                 (simple-noun-phrase (article the) (noun class))))))

(test-amb (parse '(the professor lectures to the student with the cat))
          &~> '(
                (sentence
                 (simple-noun-phrase (article the) (noun professor))
                 (verb-phrase
                  (verb-phrase
                   (verb lectures)
                   (prep-phrase (prep to)
                                (simple-noun-phrase
                                 (article the)
                                 (noun student))))
                  (prep-phrase (prep with)
                               (simple-noun-phrase
                                (article the)
                                (noun cat)))))
                ;; next
                (sentence
                 (simple-noun-phrase (article the) (noun professor))
                 (verb-phrase
                  (verb lectures)
                  (prep-phrase (prep to)
                               (noun-phrase
                                (simple-noun-phrase
                                 (article the) (noun student))
                                (prep-phrase (prep with)
                                             (simple-noun-phrase
                                              (article the)
                                              (noun cat)))))))
                ))

(test-end "sentence puzzles")

(test-end "amb evaluator")


(test-begin "query")
(define-syntax test-quote
  (syntax-rules (=>)
    ((test-quote expr => expect)
     (test-quote expr expect))
    ((test-quote name expr => expect)
     (test-quote expr expect))
    ((test-quote expr expect)
     (test-equal expect (query/eval 'expr)))))

(test-quote (job ?x (computer programmer))
             => '((job (Fect Cy D) (computer programmer))
                  (job (Hacker Alyssa P) (computer programmer))))

(test-quote (job (Fect Cy D) ?)
            '((job (Fect Cy D) (computer programmer))))

(test-quote "Exercise 4.61"
            (next-to ?x ?y in (1 (2 3) 4))
            => '((next-to (2 3) 4 in (1 (2 3) 4))
                 (next-to 1 (2 3) in (1 (2 3) 4))))

(test-quote "Exercise 4.63 (grandparent)"
            (grandparent Adam ?x ?y) => '((grandparent Adam Cain Enoch)))

(test-quote "Exercise 4.64 (son-of)"
            (son-of Ada ?x ?y)
            => '((son-of Ada Lamech Jubal)
                 (son-of Ada Lamech Jabal)))

(test-end "query")

(test-end "evaluator")

(test-end "tests")
