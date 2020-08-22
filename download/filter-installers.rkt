#lang racket/base

(require racket/pretty
         racket/set
         racket/match
         racket/file
         racket/cmdline)

;; this code is used to filter the lines generated by the racket
;; bundling scripts for inclusion in the download site.

;; run it with
;; racket filter-installers.rkt <installers.txt> <filtered-installers.txt>

;; filter out lines that match a predicate, report on the remaining set
(define (filter-out description pred l)
  (define new-l (filter (compose not pred) l))
  (printf "discarding these ~v:\n" description)
  (pretty-print (set-subtract l new-l))
  (printf "remaining lines: ~v\n" (length new-l))
  new-l)

;; a line contains a size, a tab, and a path. Parse it and return
;; just the path
(define (line-path l)
  (match l
    [(regexp #px"^[0-9]+\t(.*)$" (list _ path)) path]
    [other (error 'line-path "unexpected line format: ~e" l)]))

;; 1) Remove non-installers:

(define ignored-extensions
  (list "ico" "png" "rktd" "html" "htaccess" "txt"))

(define (ignored-extension? str) (member str ignored-extensions))

(define (non-installer? line)
  (match-define (list _ extension)
    (regexp-match #px"\\.([^.]*)$" (line-path line)))
  (ignored-extension? extension))

;; 2) remove natipkg builds

(define (natipkg? l)
  (regexp-match? #px"-natipkg" (line-path l)))

;; 3) remove win/mac/linux tgz builds

(define (win-mac-linux-tgz? l)
  (regexp-match? #px"(macos|win32|linux).*tgz$" (line-path l)))

;; 4) put CS builds later
;; (This is necessary because the page build scripts currently
;; order the choices based on the order of the lines in the installer
;; script.)

(define (has-cs? l)
  (regexp-match #px"-cs" (line-path l)))

(define (cs<? a b)
  (cond [(and (not (has-cs? a)) (has-cs? b)) #t]
        [else #f]))

;; read the lines from the input file, write the filtered
;; lines to the output file. Overwrite the output file
;; if it exists.

(define (go input-file output-file)
  (define lines (file->lines input-file))

  (printf "lines in installer-data: ~v\n" (length lines))

  (define output-lines
    (sort
     (filter-out
      "win/mac/linux tgz installers" win-mac-linux-tgz?
      (filter-out
       "natipkg installers" natipkg?
       (filter-out
        "non-installers" non-installer? lines)))
     cs<?))

  (call-with-output-file output-file
    #:exists 'truncate
    (λ (port)
      (for-each (λ (l) (displayln l port)) output-lines))))

(module+ main
  (command-line #:args (input-file output-file)
                (go input-file output-file)))


