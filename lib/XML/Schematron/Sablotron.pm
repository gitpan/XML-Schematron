package XML::Schematron::Sablotron;

use strict;
use XML::Schematron;
use XML::Sablotron;

use vars qw/@ISA $VERSION/;

@ISA = qw/XML::Schematron/;
$VERSION = $XML::Schematron::VERSION;

sub tests_to_xsl {
    my $self = shift;
    my $template;
    my $mode = 'M0';
    my $ns = qq{xmlns:xsl="http://www.w3.org/1999/XSL/Transform"};

    $template = qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <xsl:stylesheet $ns version="1.0">
    <xsl:output $ns method="text"/>
    <xsl:template $ns match="/">
    <xsl:apply-templates $ns select="/" mode="$mode"/>};

    
    my $last_context_path = '';
    my $priority = 4000;
    foreach my $testref (@{$self->{tests}}) {
        my ($test, $context_path, $message, $test_type, $pattern) = @{$testref};
        $context_path =~ s/"/'/g if $context_path =~ /"/g;
        $test =~ s/</&lt;/g;
        $test =~ s/>/&gt;/g;
        $message =~ s/\n//g;
        $message .= "\n";

        if ($context_path ne $last_context_path) {
             $template .= qq{\n<xsl:apply-templates $ns mode="$mode"/>\n} unless $priority == 4000;
             $template .= qq{</xsl:template>\n<xsl:template $ns match="$context_path" priority="$priority" mode="$mode">};
             $priority--;
        }
        
        if ($test_type eq 'assert') {
            $template .= qq{<xsl:choose $ns>
                            <xsl:when $ns test="$test"/>
                            <xsl:otherwise $ns>In pattern $pattern: $message</xsl:otherwise>
                            </xsl:choose>};
        }
        else {
            $template .= qq{<xsl:if $ns test="$test">In pattern $pattern: $message</xsl:if>};
        }
        $last_context_path = $context_path;
    }

    
    $template .= qq{<xsl:apply-templates $ns mode="$mode"/>\n</xsl:template>\n
                    <xsl:template xmlns:xsl="http://www.w3.org/1999/XSL/Transform" match="text()" priority="-1" mode="M0"/>
                    </xsl:stylesheet>};
    
    #print "$template\n";
    return $template;
}

sub verify {
    my $self = shift;    
    my ($xml_file) = $_[0];
    my ($data, $do_array);
    $do_array++ if wantarray;

    $self->build_tests if $self->{schema};

    my $template = $self->tests_to_xsl;
    #print "$template\n";

    open (XML, "$xml_file") || die "Could not open file $xml_file $!\n"; 

    local $/;
    $data = <XML>;
    close XML;

    my $xslt_processor = XML::Sablotron->new();
    my $result = ' ';

    my $args = ['template', "$template", 'xml_resource', "$data"];

    my $retcode = $xslt_processor->RunProcessor("arg:/template", "arg:/xml_resource", "arg:/result", 
                                                [], $args);
        if ($retcode) {
          die "Sablotron could not process the XML file";
        }

   my $ret_string = $xslt_processor->GetResultArg("result");

   if ($do_array) {
       my @ret_array = split "\n", $ret_string;
       return @ret_array;
   }

   return $ret_string;
}

sub dump_xsl {
    my $self = shift;
    my $stylesheet = $self->tests_to_xsl;;
    return $stylesheet; 
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

XML::Schematron::Sablotron - Perl extension for validating XML with XPath/XSLT expressions.

=head1 SYNOPSIS


  use XML::Schematron::Sabotron;
  my $pseudotron = XML::Schematron::Sablotron->new(schema => 'my_schema.xml');
  my $messages = $pseudotron->verify('my_doc.xml');

  if ($messages) {
      # we got warnings or errors during validation...
      ...
  }

  OR, in an array context:

  my $pseudotron = XML::Schematron::Sablotron->new(schema => 'my_schema.xml');
  my @messages = $pseudotron->verify('my_doc.xml');


  OR, just get the generated xsl:

  my $pseudotron = XML::Schematron::Sablotron->new(schema => 'my_schema.xml');
  my $xsl = $pseudotron->dump_xsl; # returns the internal XSLT stylesheet.


=head1 DESCRIPTION

XML::Schematron::Sablotron serves as a simple validator for XML based on Rick JELLIFFE's Schematron XSLT script. A Schematron
schema defines a set of rules in the XPath language that are used to examine the contents of an XML document tree.

A simplified example: 

<schema>
 <pattern>
  <rule context="page">
   <assert test="count(*)=count(title|body)">The page element may only contain title or body elements.</assert> 
   <assert test="@name">A page element must contain a name attribute.</assert> 
   <report test="string-length(@name) &lt; 5">A page element name attribute must be at least 5 characters long.</report> 
  </rule>
 </pattern>
</schema>

Note that an 'assert' rule will return if the result of the test expression is I<not> true, while a 'report' rule will return
only if the test expression evalutes to true.

=head1 METHODS

=over 4

=item new(schema => 'my_schema_file.xml')

The 'new' constructor requires the argument 'schema' that should be set (using a key/value pair or single hash) to the
location of the schema you wish to use.

=item validate('my_xml_file.xml')

The validate method takes the path to the XML document that you wish to validate as its sole argument. It returns the
messages (the text() nodes) of any 'assert' or 'report' rules that are returned during validation. When called in an array    
context, this method returns an array of all messages generated during validation. When called in a a scalar context, this
method returns a concatenated string of all output.

=item dump_xsl;

The dump_xsl method will return the internal XSLT script created from your schema.

=back

=head1 CONFORMANCE

Internally, XML::Schematron::Sablotron uses the Sablotron XSLT proccessor and, while this proccessor is not 100% compliant
with the XSLT spec at the time of this writing, it is evolving quickly and is very near completion. It is therefore possible
that you might use a completely valid XSLT expression within one of your schema's tests that will cause this module to die
unexpectedly. 

For those platforms on which Sablotron is not available, please see the documentation for XML::Schematron::XPath (also in this
distribution) for an alternative. 

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2000 Kip Hampton. All rights reserved. This program is free software; you can redistribute it and/or modify it  
under the same terms as Perl itself.

=head1 SEE ALSO

For information about Schematron, sample schemas, and tutorials to help you write your own schmemas, please visit the
Schematron homepage at: http://www.ascc.net/xml/resource/schematron/

For information about how to install Sablotron and the necessary XML::Sablotron Perl module, please see the Ginger Alliance
homepage at: http://www.gingerall.com/ 

For detailed information about the XPath syntax, please see the W3C XPath Specification at: http://www.w3.org/TR/xpath.html 

=cut
