# This file was automatically generated by SWIG (http://www.swig.org).
# Version 1.3.31
#
# Don't modify this file, modify the SWIG interface instead.

package GetPvalueForT;
require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
package GetPvalueForTc;
bootstrap GetPvalueForT;
package GetPvalueForT;
@EXPORT = qw( );

# ---------- BASE METHODS -------------

package GetPvalueForT;

sub TIEHASH {
    my ($classname,$obj) = @_;
    return bless $obj, $classname;
}

sub CLEAR { }

sub FIRSTKEY { }

sub NEXTKEY { }

sub FETCH {
    my ($self,$field) = @_;
    my $member_func = "swig_${field}_get";
    $self->$member_func();
}

sub STORE {
    my ($self,$field,$newval) = @_;
    my $member_func = "swig_${field}_set";
    $self->$member_func($newval);
}

sub this {
    my $ptr = shift;
    return tied(%$ptr);
}


# ------- FUNCTION WRAPPERS --------

package GetPvalueForT;

*GetPvalueForT = *GetPvalueForTc::GetPvalueForT;

# ------- VARIABLE STUBS --------

package GetPvalueForT;

1;