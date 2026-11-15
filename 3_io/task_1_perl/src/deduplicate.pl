use strict;
use warnings;

# Return decoded fields and the original bytes of one logical record.
sub read_record {
    my ($text, $separator) = @_;
    my $start = pos($$text) // 0;
    return if $start == length $$text;
    my @fields;
    while (1) {
        if ($$text =~ /\G"((?:[^"]|"")*)"/gc) {
            my $field = $1;
            $field =~ s/""/"/g;
            push @fields, $field;
        } elsif ($$text =~ /\G((?:(?!\Q$separator\E|["\r\n]).)*)/gc) {
            push @fields, $1;
        }
        next if $$text =~ /\G\Q$separator\E/gc;
        last if pos($$text) == length $$text;
        last if $$text =~ /\G(?:\r\n|\n|\r)/gc;
        die "Malformed CSV record at byte $start\n";
    }
    return (\@fields, substr($$text, $start, pos($$text) - $start));
}

my ($path, $key, $separator) = @ARGV;
$separator //= ',';
die "Usage: run.cmd INPUT KEY [SEPARATOR]\n" unless @ARGV == 2 || @ARGV == 3;
die "Separator must be one ASCII character other than quote or newline\n"
    unless $separator =~ /\A[\x01-\x7f]\z/ && $separator !~ /["\r\n]/;

open my $input, '<:raw', $path or die "Cannot open '$path': $!\n";
my $text = do { local $/; <$input> } // '';
close $input or die "Cannot close '$path': $!\n";
pos($text) = 0;
my $bom = $text =~ /\G(\xEF\xBB\xBF)/gc ? $1 : '';
my ($header, $header_bytes) = read_record(\$text, $separator);
die "CSV header is missing\n" unless $header;
my @columns = grep { $header->[$_] eq $key } 0 .. $#$header;
die "Key column '$key' must occur exactly once in the header\n" unless @columns == 1;
my ($column) = @columns;

my %seen;
my @output = ($bom, $header_bytes);
my $record_number = 1;
while (my ($fields, $bytes) = read_record(\$text, $separator)) {
    ++$record_number;
    die "Wrong number of fields in record $record_number\n" unless @$fields == @$header;
    my $value = $fields->[$column];
    next if exists $seen{$value};
    $seen{$value} = 1;
    push @output, $bytes;
}

binmode STDOUT, ':raw' or die "Cannot configure output: $!\n";
print @output or die "Cannot write output: $!\n";
