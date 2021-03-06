function hdl=traceplot(obj,pname,chain_id,ma_window)
% Make a trace plot from the mcmc chains
%
% ::
%
%    hdl = traceplot(mcobj,pname);
%    hdl = traceplot(mcobj,pname,chain_id);
%    hdl = traceplot(mcobj,pname,chain_id,ma_window);
%
% Args:
%
%    mcobj (mcmc object): mcmc object
%
%    pname (str): parameter to make the trace plot
%
%    chain_id (vector of int): id of the chain to use
%
%    ma_window (int): window size if using moving average smoothing.
%
% Returns:
%    :
%
%    - **hdl** (handle object): handle to plot object
%

if nargin<4

    ma_window=[];

    if nargin<3

        chain_id=[];

    end

end

is_ma=isempty(obj.nchains)==1||(~isempty(chain_id) && numel(chain_id)==1);

if isempty(ma_window)

    ma_window=20;

end

x=load_draws(obj,pname,chain_id);

t=(1:obj.npop)+obj.start-1;

plot(t.',x.')

if is_ma

    xma=nan(size(x));

    stretch0=-ma_window:ma_window;

    for ii=1:obj.npop

        stretch=stretch0+ii;

        if isempty(stretch)||min(stretch)<1||max(stretch)>obj.npop

            continue

        end

        xma(:,ii)=mean(x(:,stretch),2);

    end

    hold on

    plot(t.',xma.','linewidth',2,'color',[0,0,0])

end

axis tight

title(pname)

hold off

if nargout

    hdl=get(gca,'children');

end

end