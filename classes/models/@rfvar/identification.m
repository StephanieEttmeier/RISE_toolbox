function varargout=identification(self,restr,shock_names,varargin)
% Parses identifying restrictions into RISE interpretable identification function
%
% Note:
%    This function is a part of a general workflow. See XXXXXXXXXX to check the workflow.
%
% ::
%
%    Rfunc = identification(var, restr, shock_names, varargin);
%
% Args:
%    var (rfvar object): rfvar object
%    restr : restrictions can take two forms
%
%       - **'choleski'**: choleski identification. Supply the ordering as a cell array as varargin{1}
%       - **cellstr**: n x 2 cell array, with n the number of restrictions.
%          A typical restriction takes the form:
%          - 'vbl@shk','sign'
%          - 'vbl{lags}@shk','sign'
%          where sign = +|-
%          where shk is the name of the shock
%          where vbl is the name of the endogenous variable affected by
%          shock
%          lags with defaut 0 is the list of lags at which the shock
%          affects the variable with a 'sign' sign. lags is any valid
%          expression that matlab can evaluate such as 0, 0:3, [1,4,5],
%          [1,inf,2,5] or more generally a:b, [a:b,c,d], etc.
%
%    shock_names (cellstr): cell of structural shock names
%
% Returns:
%    :
%
%    - **Rfunc** (function handle): a function that takes parameters and then returns structural shock matrix. This function function is not intended to be used used on its own, and supposed to be used as an argument in different functions.
%
% See also:
%    - :func:`autocov <var.autocov>`
%    - :func:`forecast <var.forecast>`
%    - :func:`historical_decomposition <var.historical_decomposition>`
%    - :func:`irf <var.irf>`
%    - :func:`variance_decomposition <var.variance_decomposition>`
%

% if choleski, restr=choleski, varargin={ordering}, where
% ordering is the list of the variables in their new order
%
% else restr=... varargin={agnostic,max_trials,debug}

% shock_names=abstvar.create_variable_names(self.nvars,'shock',shock_names);

if nargin<2

    restr=[];

end

if isempty(restr)

    restr='choleski';

end

if ischar(restr)

    if ~isempty(varargin)

        v1=varargin{1};

        if ~iscellstr(v1)

            error('ordering must be a cellstr')

        end

        ordering=struct('old',{self.endogenous},...
            'new',{v1});

        varargin{1}=ordering;

    end

    if ~strcmp(restr,'choleski')

        error('unknown type of identification')

    end

    [varargout{1:nargout}]=vartools.choleski(self.nvars,varargin{:});

elseif iscell(restr)

    batch=read_identification_restrictions(self,restr,shock_names);

    [varargout{1:nargout}]=vartools.identification(self.nvars,...
        self.nlags,self.nx,batch,varargin{:});

else

    error('restrictions must be "choleski" or a cell ')

end

varargout{1}=memoize_identification(varargout{1});

    function fff=memoize_identification(ff)

        fff=@engine;

        function varargout=engine(varargin)

            % if unrestricted, no partitioning... but identification will
            % be bizzare. Maybe this should be discarded

            sol=solve(self,varargin{:});

            nx=self.nx; ng=self.ng; h=size(sol.Q.Q,1); nvars=self.nvars; nlags=self.nlags;

            sol_i_j=struct();

            R=cell(self.ng,h);

            batch_rows=cell(1,ng);

            batch_cols=cell(1,ng);

            for g=1:ng % panel

                [batch_rows{g},batch_cols{g}]=abstvar.map_panel(nvars,nx,nlags,g,ng);

                for jj=1:h % regime

                    sol_i_j.B=sol.B(batch_rows{g},batch_cols{g},jj);

                    sol_i_j.S=sol.S(batch_rows{g},batch_rows{g},jj);

                    [varargout{1:nargout}]=ff(sol_i_j);

                    R{g,jj}=varargout{1};

                end

            end

            varargout{1}=reconstruct_identification(R);

            function RR=reconstruct_identification(R)

                RR=zeros(ng*nvars);

                for gg=1:ng % panel

                    for jjj=1:h % regime

                        RR(batch_rows{gg},batch_rows{gg},jjj)=R{gg,jjj};

                    end

                end

            end

        end

    end

end
