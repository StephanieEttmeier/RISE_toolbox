function [vd,retcode]=variance_decomposition(self,params,Rfunc,shock_names,varargin)
% Compute the variance decompsition of the VAR
%
% ::
%
%    [vd,retcode] = variance_decomposition(self,params,Rfunc,shock_names,varargin);
%
% Args:
%    self (var object):
%    params :(optional) parameter values
%    Rfunc (function handle): (optional) transform parameters into dynamics
%    shock_names : names of shocks
%    varargin
%
% Returns:
%    :
%
%    - **vd** (struct): a struct containing the variance decomposition:
%
%       - **infinity** (struct):
%       - **conditional** (struct):
%
%    - **retcode** (integer): This passes through the retcode given by Rfunc. Currently (2018/07/19), this output always returns 0.
%

% varargin={max_periods}

n=nargin;

set_defaults()

np=numel(params);

retcode=nan(np,1);

for ip=1:np

    if ip==1

        [Vinfi,Vi,retcode(ip),info]=do_one_parameter(params(:,ip)); %#ok<ASGLU>

        Vinfi=Vinfi(:,:,:,ones(1,np));

        Vi=Vi(:,:,:,:,ones(1,np));

    else

        [Vinfi(:,:,:,ip),Vi(:,:,:,:,ip),retcode(ip)]=do_one_parameter(params(:,ip));

    end

end

vd=struct();

shock_names=abstvar.create_variable_names(self.nvars,'shock',shock_names);

for iv=1:self.nvars

    for ireg=1:self.nregs

        data_inf=permute(Vinfi(iv,:,ireg,:),[1,2,4,3]);

        data_cond=permute(Vi(iv,:,:,ireg,:),[3,2,5,4,1]);

        if iv==1 && ireg==1

            proto_inf=ts(1,data_inf,shock_names);

            proto_cond=ts(1,data_cond,shock_names);

        end

        if self.nregs==1

            vd.infinity.(self.endogenous{iv})=set(proto_inf,'data',data_inf);

            vd.conditional.(self.endogenous{iv})=set(proto_cond,'data',data_cond);

        else

            regime=sprintf('regime_%0.0f',ireg);

            vd.infinity.(self.endogenous{iv}).(regime)=set(proto_inf,'data',data_inf);

            vd.conditional.(self.endogenous{iv}).(regime)=set(proto_cond,'data',data_cond);

        end

    end

end

    function [Vinfi,Vi,retcode,info]=do_one_parameter(param)

        [R,retcode]=Rfunc(param);

        for st=1:self.nregs

            [tmpVinfi,tmpVi,info]=vartools.variance_decomposition(...
                param.B(:,:,st),...
                R(:,:,st),...
                self.nx,...
                varargin{:});

            if st==1

                Vinfi=tmpVinfi(:,:,ones(self.nregs,1));

                Vi=tmpVi(:,:,:,ones(self.nregs,1));

            else

                Vinfi(:,:,st)=tmpVinfi;

                Vi(:,:,:,st)=tmpVi;

            end

        end

    end

    function set_defaults()

        if n<4

            shock_names=[];

            if n<3

                Rfunc=double.empty;

                if n<2

                    params=[];

                end

            end

        end

        params=solve(self,params);

        if isempty(Rfunc),Rfunc=identification(self,'choleski'); end

    end

end

