package ProblemServer::ProblemResponseWithAnswers;

=pod
=begin WSDL
        _ATTR problem       $ProblemServer::ProblemResponse The problem response
        _ATTR answers       @ProblemServer::AnswerResponse The answers
=end WSDL
=cut
sub new {
    my $self = shift;
    $self = {};
    bless $self;
    return $self;
}

1;
