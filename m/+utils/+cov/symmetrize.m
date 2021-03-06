function A=symmetrize(A)
% INTERNAL FUNCTION: Makes a square matrix symmetric
%
% ::
%
%   A=symmetrize(A)
%
% Args:
%
%    - **A** [square matrix]
%
% Returns:
%    :
%
%    - **A** [square matrix] : :math:`\frac{A + A^{T}}{2}`
%

A=.5*(A+A.');
end

