package ProblemServer::GeneratorResponse;

=pod
=begin WSDL
        _ATTR id $string The ID of the problem
        _ATTR problems @ProblemServer::ProblemResponse An array of problems that were generated.
=end WSDL
=cut
sub new {
    my $self = shift;
    $self = {};

    bless $self;
    return $self;
}

1;
