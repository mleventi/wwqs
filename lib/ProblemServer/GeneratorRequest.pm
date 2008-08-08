package ProblemServer::GeneratorRequest;

=pod
=begin WSDL
        _ATTR id $string The ID of this generator request.
        _ATTR trials $string The number of attempts at generation
        _ATTR problem $ProblemServer::ProblemRequest The problem to be generated
=end WSDL
=cut
sub new {
    my $self = shift;
    $self={};
    bless $self;
    return $self;
}

1;
