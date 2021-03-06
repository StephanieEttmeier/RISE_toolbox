function db=expanding(db,func,varargin)
% Applies a function to an expanding window of the time series
%
% ::
%
%    h = expanding(db,func);
%    h = expanding(db,func,varargin);
%
% Args:
%
%    db (ts object): time series object to get data
%
%    func: function that will apply to the expanding window of the time
%      series. The function is recursively applied to the data 1:t for
%      t=1,2,3,...,T, where T is the number of observations
%
%    varargin: additional arguments to func
%

window=[];

db=ts_roll_or_expand(db,func,window,varargin{:});

end