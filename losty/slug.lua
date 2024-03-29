--
-- Generated from slug.lt
--
local set = require("losty.set")
local to = require("losty.to")
local str = require("losty.str")
local stops_en_txt = [==[
a
able
about
above
abst
accordance
according
accordingly
across
act
actually
added
adj
affected
affecting
affects
after
afterwards
again
against
ah
all
almost
alone
along
already
also
although
always
am
among
amongst
an
and
announce
another
any
anybody
anyhow
anymore
anyone
anything
anyway
anyways
anywhere
apparently
approximately
are
aren
arent
arise
around
as
aside
ask
asking
at
auth
available
away
awfully
b
back
be
became
because
become
becomes
becoming
been
before
beforehand
begin
beginning
beginnings
begins
behind
being
believe
below
beneath
beside
besides
between
beyond
biol
both
bottom
brief
briefly
but
by
c
ca
came
can
cannot
can't
cause
causes
certain
certainly
co
com
come
comes
contain
containing
contains
could
couldn't
coz
d
date
despite
did
didn't
different
do
does
doesn't
doing
done
don't
down
downwards
due
during
e
each
ed
edu
effect
eg
eight
eighty
either
else
elsewhere
end
ending
enough
especially
et
et-al
etc
even
ever
every
everybody
everyone
everything
everywhere
ex
except
f
far
few
ff
fifth
first
five
fix
followed
following
follows
for
former
formerly
forth
found
four
from
further
furthermore
g
gave
get
gets
getting
give
given
gives
giving
go
goes
gone
got
gotten
h
had
happens
hardly
has
hasn't
have
haven't
having
he
he'd
he'll
hence
her
here
hereafter
hereby
herein
heres
hereupon
hers
herself
he's
hi
hid
him
himself
his
hither
home
how
howbeit
however
hundred
i
id
i'd
ie
if
i'll
i'm
immediate
immediately
importance
important
in
inc
indeed
index
information
instead
into
invention
inward
is
isn't
it
itd
it'll
its
itself
i've
j
just
k
keep
keeps
kept
kg
km
know
known
knows
l
largely
last
lately
later
latter
latterly
least
less
lest
let
lets
like
liked
likely
line
little
'll
look
looking
looks
ltd
m
made
mainly
make
makes
many
may
maybe
me
mean
means
meantime
meanwhile
merely
mg
might
million
mine
miss
ml
more
moreover
most
mostly
mr
mrs
much
mug
must
my
myself
n
na
name
namely
nay
nd
near
nearly
necessarily
necessary
need
needs
neither
never
nevertheless
new
next
no
nobody
non
none
nonetheless
noone
nor
normally
nos
not
noted
nothing
notwithstanding
now
nowhere
o
obtain
obtained
obviously
of
off
often
oh
ok
okay
old
omitted
on
once
one
ones
only
onto
or
ord
other
others
otherwise
ought
our
ours
ourselves
out
outside
over
overall
owing
own
p
page
pages
part
particular
particularly
past
per
perhaps
placed
please
plus
poorly
possible
possibly
potentially
pp
predominantly
present
previously
primarily
probably
promptly
proud
provides
put
q
que
quickly
quite
qv
r
ran
rather
rd
re
readily
really
recent
recently
ref
refs
regarding
regardless
regards
related
relatively
research
respectively
resulted
resulting
results
right
run
s
said
same
saw
say
saying
says
sec
section
see
seeing
seem
seemed
seeming
seems
seen
self
selves
sent
seven
several
shall
she
she'd
she'll
she's
should
shouldn't
show
showed
shown
showns
shows
significant
significantly
similar
similarly
since
sincere
sincerely
six
slightly
so
some
somebody
somehow
someone
somethan
something
sometime
sometimes
somewhat
somewhere
soon
sorry
specifically
specified
specify
specifying
still
stop
strongly
sub
substantially
successfully
such
sufficiently
suggest
sup
sure
t
take
taken
taking
tell
tends
th
than
thank
thanks
thanx
that
that'll
thats
that've
the
their
theirs
them
themselves
then
thence
there
thereafter
thereby
thered
therefore
therein
there'll
thereof
therere
theres
thereto
thereupon
there've
these
they
they'd
they'll
they're
they've
think
this
those
thou
though
thoughh
thousand
throug
through
throughout
thru
thus
til
tip
to
together
too
took
toward
towards
tried
tries
truly
try
trying
ts
twice
two
u
un
under
underneath
unfortunately
unless
unlike
unlikely
until
unto
up
upon
ups
us
use
used
useful
usefully
usefulness
uses
using
usually
v
value
various
've
very
via
viz
vol
vols
vs
w
want
wants
was
wasn't
way
we
we'd
welcome
well
we'll
went
were
we're
weren't
we've
what
whatever
what'll
whats
when
whence
whenever
where
whereafter
whereas
whereby
wherein
wheres
whereupon
wherever
whether
which
while
whim
whither
who
whod
whoever
whole
who'll
whom
whomever
whos
whose
why
widely
willing
wish
with
within
without
won't
words
world
would
wouldn't
www
x
y
yes
yet
you
you'd
you'll
your
you're
yours
yourself
yourselves
you've
z
zero
]==]
local charmap = {
    ["À"] = "A"
    , ["Á"] = "A"
    , ["Â"] = "A"
    , ["Ã"] = "A"
    , ["Ä"] = "A"
    , ["Å"] = "A"
    , ["Æ"] = "AE"
    , ["Ç"] = "C"
    , ["È"] = "E"
    , ["É"] = "E"
    , ["Ê"] = "E"
    , ["Ë"] = "E"
    , ["Ì"] = "I"
    , ["Í"] = "I"
    , ["Î"] = "I"
    , ["Ï"] = "I"
    , ["Ð"] = "D"
    , ["Ñ"] = "N"
    , ["Ò"] = "O"
    , ["Ó"] = "O"
    , ["Ô"] = "O"
    , ["Õ"] = "O"
    , ["Ö"] = "O"
    , ["Ő"] = "O"
    , ["Ø"] = "O"
    , ["Ù"] = "U"
    , ["Ú"] = "U"
    , ["Û"] = "U"
    , ["Ü"] = "U"
    , ["Ű"] = "U"
    , ["Ý"] = "Y"
    , ["Þ"] = "TH"
    , ["ß"] = "ss"
    , ["à"] = "a"
    , ["á"] = "a"
    , ["â"] = "a"
    , ["ã"] = "a"
    , ["ä"] = "a"
    , ["å"] = "a"
    , ["æ"] = "ae"
    , ["ç"] = "c"
    , ["è"] = "e"
    , ["é"] = "e"
    , ["ê"] = "e"
    , ["ë"] = "e"
    , ["ì"] = "i"
    , ["í"] = "i"
    , ["î"] = "i"
    , ["ï"] = "i"
    , ["ð"] = "d"
    , ["ñ"] = "n"
    , ["ò"] = "o"
    , ["ó"] = "o"
    , ["ô"] = "o"
    , ["õ"] = "o"
    , ["ö"] = "o"
    , ["ő"] = "o"
    , ["ø"] = "o"
    , ["ù"] = "u"
    , ["ú"] = "u"
    , ["û"] = "u"
    , ["ü"] = "u"
    , ["ű"] = "u"
    , ["ý"] = "y"
    , ["þ"] = "th"
    , ["ÿ"] = "y"
    , ["ẞ"] = "SS"
    , ["α"] = "a"
    , ["β"] = "b"
    , ["γ"] = "g"
    , ["δ"] = "d"
    , ["ε"] = "e"
    , ["ζ"] = "z"
    , ["η"] = "h"
    , ["θ"] = "8"
    , ["ι"] = "i"
    , ["κ"] = "k"
    , ["λ"] = "l"
    , ["μ"] = "m"
    , ["ν"] = "n"
    , ["ξ"] = "3"
    , ["ο"] = "o"
    , ["π"] = "p"
    , ["ρ"] = "r"
    , ["σ"] = "s"
    , ["τ"] = "t"
    , ["υ"] = "y"
    , ["φ"] = "f"
    , ["χ"] = "x"
    , ["ψ"] = "ps"
    , ["ω"] = "w"
    , ["ά"] = "a"
    , ["έ"] = "e"
    , ["ί"] = "i"
    , ["ό"] = "o"
    , ["ύ"] = "y"
    , ["ή"] = "h"
    , ["ώ"] = "w"
    , ["ς"] = "s"
    , ["ϊ"] = "i"
    , ["ΰ"] = "y"
    , ["ϋ"] = "y"
    , ["ΐ"] = "i"
    , ["Α"] = "A"
    , ["Β"] = "B"
    , ["Γ"] = "G"
    , ["Δ"] = "D"
    , ["Ε"] = "E"
    , ["Ζ"] = "Z"
    , ["Η"] = "H"
    , ["Θ"] = "8"
    , ["Ι"] = "I"
    , ["Κ"] = "K"
    , ["Λ"] = "L"
    , ["Μ"] = "M"
    , ["Ν"] = "N"
    , ["Ξ"] = "3"
    , ["Ο"] = "O"
    , ["Π"] = "P"
    , ["Ρ"] = "R"
    , ["Σ"] = "S"
    , ["Τ"] = "T"
    , ["Υ"] = "Y"
    , ["Φ"] = "F"
    , ["Χ"] = "X"
    , ["Ψ"] = "PS"
    , ["Ω"] = "W"
    , ["Ά"] = "A"
    , ["Έ"] = "E"
    , ["Ί"] = "I"
    , ["Ό"] = "O"
    , ["Ύ"] = "Y"
    , ["Ή"] = "H"
    , ["Ώ"] = "W"
    , ["Ϊ"] = "I"
    , ["Ϋ"] = "Y"
    , ["ş"] = "s"
    , ["Ş"] = "S"
    , ["ı"] = "i"
    , ["İ"] = "I"
    , ["ğ"] = "g"
    , ["Ğ"] = "G"
    , ["а"] = "a"
    , ["б"] = "b"
    , ["в"] = "v"
    , ["г"] = "g"
    , ["д"] = "d"
    , ["е"] = "e"
    , ["ё"] = "yo"
    , ["ж"] = "zh"
    , ["з"] = "z"
    , ["и"] = "i"
    , ["й"] = "j"
    , ["к"] = "k"
    , ["л"] = "l"
    , ["м"] = "m"
    , ["н"] = "n"
    , ["о"] = "o"
    , ["п"] = "p"
    , ["р"] = "r"
    , ["с"] = "s"
    , ["т"] = "t"
    , ["у"] = "u"
    , ["ф"] = "f"
    , ["х"] = "h"
    , ["ц"] = "c"
    , ["ч"] = "ch"
    , ["ш"] = "sh"
    , ["щ"] = "sh"
    , ["ъ"] = "u"
    , ["ы"] = "y"
    , ["ь"] = ""
    , ["э"] = "e"
    , ["ю"] = "yu"
    , ["я"] = "ya"
    , ["А"] = "A"
    , ["Б"] = "B"
    , ["В"] = "V"
    , ["Г"] = "G"
    , ["Д"] = "D"
    , ["Е"] = "E"
    , ["Ё"] = "Yo"
    , ["Ж"] = "Zh"
    , ["З"] = "Z"
    , ["И"] = "I"
    , ["Й"] = "J"
    , ["К"] = "K"
    , ["Л"] = "L"
    , ["М"] = "M"
    , ["Н"] = "N"
    , ["О"] = "O"
    , ["П"] = "P"
    , ["Р"] = "R"
    , ["С"] = "S"
    , ["Т"] = "T"
    , ["У"] = "U"
    , ["Ф"] = "F"
    , ["Х"] = "H"
    , ["Ц"] = "C"
    , ["Ч"] = "Ch"
    , ["Ш"] = "Sh"
    , ["Щ"] = "Sh"
    , ["Ъ"] = "U"
    , ["Ы"] = "Y"
    , ["Ь"] = ""
    , ["Э"] = "E"
    , ["Ю"] = "Yu"
    , ["Я"] = "Ya"
    , ["Є"] = "Ye"
    , ["І"] = "I"
    , ["Ї"] = "Yi"
    , ["Ґ"] = "G"
    , ["є"] = "ye"
    , ["і"] = "i"
    , ["ї"] = "yi"
    , ["ґ"] = "g"
    , ["č"] = "c"
    , ["ď"] = "d"
    , ["ě"] = "e"
    , ["ň"] = "n"
    , ["ř"] = "r"
    , ["š"] = "s"
    , ["ť"] = "t"
    , ["ů"] = "u"
    , ["ž"] = "z"
    , ["Č"] = "C"
    , ["Ď"] = "D"
    , ["Ě"] = "E"
    , ["Ň"] = "N"
    , ["Ř"] = "R"
    , ["Š"] = "S"
    , ["Ť"] = "T"
    , ["Ů"] = "U"
    , ["Ž"] = "Z"
    , ["ą"] = "a"
    , ["ć"] = "c"
    , ["ę"] = "e"
    , ["ł"] = "l"
    , ["ń"] = "n"
    , ["ś"] = "s"
    , ["ź"] = "z"
    , ["ż"] = "z"
    , ["Ą"] = "A"
    , ["Ć"] = "C"
    , ["Ę"] = "E"
    , ["Ł"] = "L"
    , ["Ń"] = "N"
    , ["Ś"] = "S"
    , ["Ź"] = "Z"
    , ["Ż"] = "Z"
    , ["ā"] = "a"
    , ["ē"] = "e"
    , ["ģ"] = "g"
    , ["ī"] = "i"
    , ["ķ"] = "k"
    , ["ļ"] = "l"
    , ["ņ"] = "n"
    , ["ū"] = "u"
    , ["Ā"] = "A"
    , ["Ē"] = "E"
    , ["Ģ"] = "G"
    , ["Ī"] = "I"
    , ["Ķ"] = "K"
    , ["Ļ"] = "L"
    , ["Ņ"] = "N"
    , ["Ū"] = "U"
    , ["ė"] = "e"
    , ["į"] = "i"
    , ["ų"] = "u"
    , ["Ė"] = "E"
    , ["Į"] = "I"
    , ["Ų"] = "U"
    , ["ț"] = "t"
    , ["Ț"] = "T"
    , ["ţ"] = "t"
    , ["Ţ"] = "T"
    , ["ș"] = "s"
    , ["Ș"] = "S"
    , ["ă"] = "a"
    , ["Ă"] = "A"
    , ["Ạ"] = "A"
    , ["Ả"] = "A"
    , ["Ầ"] = "A"
    , ["Ấ"] = "A"
    , ["Ậ"] = "A"
    , ["Ẩ"] = "A"
    , ["Ẫ"] = "A"
    , ["Ằ"] = "A"
    , ["Ắ"] = "A"
    , ["Ặ"] = "A"
    , ["Ẳ"] = "A"
    , ["Ẵ"] = "A"
    , ["Ẹ"] = "E"
    , ["Ẻ"] = "E"
    , ["Ẽ"] = "E"
    , ["Ề"] = "E"
    , ["Ế"] = "E"
    , ["Ệ"] = "E"
    , ["Ể"] = "E"
    , ["Ễ"] = "E"
    , ["Ị"] = "I"
    , ["Ỉ"] = "I"
    , ["Ĩ"] = "I"
    , ["Ọ"] = "O"
    , ["Ỏ"] = "O"
    , ["Ồ"] = "O"
    , ["Ố"] = "O"
    , ["Ộ"] = "O"
    , ["Ổ"] = "O"
    , ["Ỗ"] = "O"
    , ["Ơ"] = "O"
    , ["Ờ"] = "O"
    , ["Ớ"] = "O"
    , ["Ợ"] = "O"
    , ["Ở"] = "O"
    , ["Ỡ"] = "O"
    , ["Ụ"] = "U"
    , ["Ủ"] = "U"
    , ["Ũ"] = "U"
    , ["Ư"] = "U"
    , ["Ừ"] = "U"
    , ["Ứ"] = "U"
    , ["Ự"] = "U"
    , ["Ử"] = "U"
    , ["Ữ"] = "U"
    , ["Ỳ"] = "Y"
    , ["Ỵ"] = "Y"
    , ["Ỷ"] = "Y"
    , ["Ỹ"] = "Y"
    , ["Đ"] = "D"
    , ["ạ"] = "a"
    , ["ả"] = "a"
    , ["ầ"] = "a"
    , ["ấ"] = "a"
    , ["ậ"] = "a"
    , ["ẩ"] = "a"
    , ["ẫ"] = "a"
    , ["ằ"] = "a"
    , ["ắ"] = "a"
    , ["ặ"] = "a"
    , ["ẳ"] = "a"
    , ["ẵ"] = "a"
    , ["ẹ"] = "e"
    , ["ẻ"] = "e"
    , ["ẽ"] = "e"
    , ["ề"] = "e"
    , ["ế"] = "e"
    , ["ệ"] = "e"
    , ["ể"] = "e"
    , ["ễ"] = "e"
    , ["ị"] = "i"
    , ["ỉ"] = "i"
    , ["ĩ"] = "i"
    , ["ọ"] = "o"
    , ["ỏ"] = "o"
    , ["ồ"] = "o"
    , ["ố"] = "o"
    , ["ộ"] = "o"
    , ["ổ"] = "o"
    , ["ỗ"] = "o"
    , ["ơ"] = "o"
    , ["ờ"] = "o"
    , ["ớ"] = "o"
    , ["ợ"] = "o"
    , ["ở"] = "o"
    , ["ỡ"] = "o"
    , ["ụ"] = "u"
    , ["ủ"] = "u"
    , ["ũ"] = "u"
    , ["ư"] = "u"
    , ["ừ"] = "u"
    , ["ứ"] = "u"
    , ["ự"] = "u"
    , ["ử"] = "u"
    , ["ữ"] = "u"
    , ["ỳ"] = "y"
    , ["ỵ"] = "y"
    , ["ỷ"] = "y"
    , ["ỹ"] = "y"
    , ["đ"] = "d"
}
local expander = {
    ["€"] = "euro"
    , ["₢"] = "cruzeiro"
    , ["₣"] = "franc"
    , ["£"] = "pound"
    , ["₤"] = "lira"
    , ["₥"] = "mill"
    , ["₦"] = "naira"
    , ["₧"] = "peseta"
    , ["₨"] = "rupee"
    , ["₩"] = "won"
    , ["₪"] = "shequel"
    , ["₫"] = "dong"
    , ["₭"] = "kip"
    , ["₮"] = "tugrik"
    , ["₯"] = "drachma"
    , ["₰"] = "penny"
    , ["₱"] = "peso"
    , ["₲"] = "guarani"
    , ["₳"] = "austral"
    , ["₴"] = "hryvnia"
    , ["₵"] = "cedi"
    , ["¢"] = "cent"
    , ["¥"] = "yen"
    , ["元"] = "yuan"
    , ["円"] = "yen"
    , ["﷼"] = "rial"
    , ["₠"] = "ecu"
    , ["¤"] = "currency"
    , ["฿"] = "baht"
    , ["$"] = "dollar"
    , ["₹"] = "rupee"
    , ["©"] = "(c)"
    , ["œ"] = "oe"
    , ["Œ"] = "OE"
    , ["∑"] = "sum"
    , ["®"] = "(r)"
    , ["†"] = "+"
    , ["“"] = "\""
    , ["”"] = "\""
    , ["‘"] = "'"
    , ["’"] = "'"
    , ["∂"] = "d"
    , ["ƒ"] = "f"
    , ["™"] = "tm"
    , ["℠"] = "sm"
    , ["…"] = "..."
    , ["˚"] = "o"
    , ["º"] = "o"
    , ["ª"] = "a"
    , ["•"] = "*"
    , ["∆"] = "delta"
    , ["∞"] = "infinity"
    , ["♥"] = "love"
    , ["<"] = "less"
    , [">"] = "greater"
    , ["·"] = "middot"
}
local words = set()
for w in str.gsplit(stops_en_txt, "\n", true) do
    words.add(w)
end
local stops = {words}
stops[2] = set("isn't", "aren't", "wasn't", "weren't", "hasn't", "haven't", "hadn't", "doesn't", "don't", "didn't", "won't", "wouldn't", "shan't", "shouldn't", "can't", "couldn't", "mustn't", "daren't", "needn't", "oughtn't", "mightn't")
stops[3] = stops[2].map(function(v)
    return string.gsub(v, "'", "")
end)
return function(title)
    if title then
        title = to.trim(title)
        if #title > 0 then
            title = string.lower(title)
            local out = {}
            for c in string.gmatch(title, "[%z\1-\127\194-\244][\128-\191]*") do
                if charmap[c] then
                    table.insert(out, charmap[c])
                elseif expander[c] then
                    table.insert(out, " " .. expander[c] .. " ")
                else
                    table.insert(out, c)
                end
            end
            out = table.concat(out, "")
            out = string.gsub(out, "%c+", " ")
            out = string.gsub(out, "(%w+)'s%s", "%1 ")
            out = string.gsub(out, "(%w+)'s$", "%1")
            local clean = string.gsub(out, "([%w']+)", function(w)
                for i = 1, #stops do
                    if stops[i].has(w) then
                        return ""
                    end
                end
                return w
            end)
            if #clean < 10 then
                clean = string.gsub(out, "'", "")
            else
                local _, num = string.gsub(clean, "%S+", "")
                if num < 3 then
                    clean = string.gsub(out, "'", "")
                end
            end
            clean = string.gsub(clean, "%p+", " ")
            clean = string.gsub(clean, "—", " ")
            clean = to.trim(clean)
            clean = string.gsub(clean, "%s+", "-")
            return clean
        end
    end
    return ""
end
