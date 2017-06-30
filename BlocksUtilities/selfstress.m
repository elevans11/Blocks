function [S, SS, OS, DS, DSS, DOS, D, DD] = selfstress(seg, idx, cc)
%  SELFSTRESS  Compares total fault network stressing rate to that
%              generated by a selected subset of segments.
%    [S, SS] = SELFSTRESS(SEG, IDX) uses the information in SEG to 
%    calculate the stressing rate, S, due to all faults in the network
%    and the stressing rate due only to slip on a subset of faults (the
%    "self stressing rate," SS).  SEG can either by the segment structure
%    loaded from a Mod.segment file, or the full path to that file.  The 
%    subset of faults is identified by IDX.  IDX can be an n-by-1 vector 
%    of segment indices (all integers), an n-by-4 array of segment midpoints
%    ([mid. long., mid. lat., mid. depth dip]), or an n-by-6 array of segment
%    geometry ([lon1 lat1 lon2 lat2 depth dip]).  The components of stress 
%    returned to structures S and SS, with fields xx, yy, zz, xy, xz, yz, 
%    sh (shear stress, resolved on fault in direction of slip), and nr 
%    (normal stress, resolved on fault).
%
%    [S, SS] = SELFSTRESS(SEG, IDX, CC) specifies the segment file or structure
%    and the corresponding segment indices of interest as a vector IDX, but also
%    specifies the calculation coordinates, CC, either as a structure containing
%    fields lon, lat, and z, or as an m-by-3 array containing the coordinates in 
%    the columns.
%

% Parse inputs
if ischar(seg) % if a filename was specified...
   seg = ReadSegmentTri(seg); % ...load it
end
% Calculate all segment midpoints; we might need them to find segment indices
allmlon = 0.5*(seg.lon1 + seg.lon2);
allmlat = 0.5*(seg.lat1 + seg.lat2);

% Put slips into an array
slips = zeros(3*numel(seg.lon1), 1);
slips(1:3:end) = seg.ssRate; slips(2:3:end) = seg.dsRate; slips(3:3:end) = seg.tsRate;

if sum(idx) == sum(round(idx)) % if indices were specified...
   % make the appropriate
   o1   = seg.lon1(idx);
   o2   = seg.lon2(idx);
   a1   = seg.lat1(idx);
   a2   = seg.lat2(idx);
   ld   = seg.lDep(idx);
   dip  = seg.dip(idx);
   [fm.lon] = 0.5*(o1 + o2);
   [fm.lat] = 0.5*(a1 + a2);
   [fm.z] = -ld./2;
elseif size(idx, 2) == 6
   o1   = idx(:, 1);
   o2   = idx(:, 2);
   a1   = idx(:, 3);
   a2   = idx(:, 4);
   ld   = idx(:, 5);
   dip  = idx(:, 6);   
   [fm.lon] = 0.5*(o1 + o2);
   [fm.lat] = 0.5*(a1 + a2);
   [fm.z] = -ld./2;
   [junk, idx] = ismember([fm.lon fm.lat], [allmlon allmlat], 'rows');
else
   fm.lon = idx(:, 1);
   fm.lat = idx(:, 2);
   fm.z = -idx(:, 3);
   dip  = idx(:, 4);
   [junk, idx] = ismember([fm.lon fm.lat], [allmlon allmlat], 'rows');
   o1   = seg.lon1(idx);
   o2   = seg.lon2(idx);
   a1   = seg.lat1(idx);
   a2   = seg.lat2(idx);
end

if exist('cc', 'var')
   if ~isstruct(cc)
      fm.lon = cc(:, 1); 
      fm.lat = cc(:, 2);
      fm.z   = -cc(:, 3);
   else
      fm = cc;
   end
end

% Calculate the partials
G = GetElasticStrainPartials(seg, fm);

% Calculate the strains
s = G*(slips./1e6); % Convert slips to km here for agreement with stress units
% Isolate the columns needed for self stress
sidx = repmat(3*(idx(:)-1), 1, 3) + repmat(1:3, length(idx), 1); sidx = sort(sidx(:));
ss = G(:, sidx)*(slips(sidx)./1e6);
% Isolate the columns needed for other stress 
oidx = setdiff(1:size(G, 2), sidx);
os = G(:, oidx)*(slips(oidx)./1e6);
keyboard
% Convert to stresses
[S.xx, S.yy, S.zz, S.xy, S.xz, S.yz] = deal(s(1:6:end), s(2:6:end), s(3:6:end), s(4:6:end), s(5:6:end), s(6:6:end));
[SS.xx, SS.yy, SS.zz, SS.xy, SS.xz, SS.yz] = deal(ss(1:6:end), ss(2:6:end), ss(3:6:end), ss(4:6:end), ss(5:6:end), ss(6:6:end));
[OS.xx, OS.yy, OS.zz, OS.xy, OS.xz, OS.yz] = deal(os(1:6:end), os(2:6:end), os(3:6:end), os(4:6:end), os(5:6:end), os(6:6:end));

% Load and add triangular stains, if available
%fts = dir('/Users/jack/Documents/MATLAB/meade_blocks/cascadia/blocks/result/safstrain/saftristrain*');
%if ~isempty(fts)
%   for i = 1:length(fts)
%      load(['/Users/jack/Documents/MATLAB/meade_blocks/cascadia/blocks/result/safstrain/' fts(i).name], 'ts*')
%   end
%end
%% find which we're using
%a = who('ts*');
%for i = 1:length(a)
%   tsz(i) = length(getfield(eval(a{i}), 'xx'));
%end
%uset = find(tsz == length(S.xx));
%
%tS = structmath(S, eval(a{uset}), 'plus');
%tSS = structmath(SS, eval(a{uset}), 'plus');
%
%S = tS;
%SS = tSS;
 
% Convert to stress
mu = 3e10;
lambda = 3e10;
S = StrainToStress(S, lambda, mu);
SS = StrainToStress(SS, lambda, mu);
OS = StrainToStress(OS, lambda, mu);
% Calculate mean stresses
p = 1/3*(S.xx + S.yy + S.zz);
sp = 1/3*(SS.xx + SS.yy + SS.zz);
op = 1/3*(OS.xx + OS.yy + OS.zz);

[P.xx, P.yy, P.zz] = deal(p);
[P.xy, P.xz, P.yz] = deal(0);
[SP.xx, SP.yy, SP.zz] = deal(sp);
[SP.xy, SP.xz, SP.yz] = deal(0);
[OP.xx, OP.yy, OP.zz] = deal(op);
[OP.xy, OP.xz, OP.yz] = deal(0);

% Calculate deviatoric stresses
DS = structmath(S, P, 'minus');
DSS = structmath(SS, SP, 'minus');
DOS = structmath(OS, OP, 'minus');

% Project the stresses onto fault geometry
strike = azim(o1, a1, o2, a2);
rake = rad_to_deg(atan2(seg.dsRate(idx), seg.ssRate(idx)));
[S.nr, S.sh, SS.nr, SS.sh, OS.nr, OS.sh, DS.nr, DS.sh, DSS.nr, DSS.sh, DOS.nr, DOS.sh] = deal(zeros(length(idx), 1));
for i = 1:length(idx)
   [S.nr(i), S.sh(i)] = rotplane(strike(i), dip(i), rake(i), [S.xx(i), S.yy(i), S.zz(i), S.xy(i), S.xz(i), S.yz(i)]);
   [SS.nr(i), SS.sh(i)] = rotplane(strike(i), dip(i), rake(i), [SS.xx(i), SS.yy(i), SS.zz(i), SS.xy(i), SS.xz(i), SS.yz(i)]);
   [OS.nr(i), OS.sh(i)] = rotplane(strike(i), dip(i), rake(i), [OS.xx(i), OS.yy(i), OS.zz(i), OS.xy(i), OS.xz(i), OS.yz(i)]);

   [DS.nr(i), DS.sh(i)] = rotplane(strike(i), dip(i), rake(i), [DS.xx(i), DS.yy(i), DS.zz(i), DS.xy(i), DS.xz(i), DS.yz(i)]);
   [DSS.nr(i), DSS.sh(i)] = rotplane(strike(i), dip(i), rake(i), [DSS.xx(i), DSS.yy(i), DSS.zz(i), DSS.xy(i), DSS.xz(i), DSS.yz(i)]);
   [DOS.nr(i), DOS.sh(i)] = rotplane(strike(i), dip(i), rake(i), [DOS.xx(i), DOS.yy(i), DOS.zz(i), DOS.xy(i), DOS.xz(i), DOS.yz(i)]);
end

% Calculate right-lateral Coulomb stress
fric = 0.4;
S.csc = -S.sh - fric.*S.nr;
SS.csc = -SS.sh - fric.*SS.nr;
OS.csc = -OS.sh - fric.*OS.nr;

DS.csc = -DS.sh - fric.*DS.nr;
DSS.csc = -DSS.sh - fric.*DSS.nr;
DOS.csc = -DOS.sh - fric.*DOS.nr;

% Calculate percent differences
D.sh = OS.sh./SS.sh*100;
D.nr = OS.nr./SS.nr*100;
D.csc = OS.csc./SS.csc*100;

DD.sh = DOS.sh./DSS.sh*100;
DD.nr = DOS.nr./DSS.nr*100;
DD.csc = DOS.csc./DSS.csc*100;



% some plots
figure
mycline([o1'; o2'], [a1'; a2'], log10(S.sh)); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('All stress, shear')
ca = caxis; cb = colorbar; ylabel(cb, 'log_{10}\tau')

figure
mycline([o1'; o2'], [a1'; a2'], log10(SS.sh)); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('Self stress, shear')
caxis(ca), colormap(jet), cb = colorbar; ylabel(cb, 'log_{10}\tau')

figure
mycline([o1'; o2'], [a1'; a2'], log10(OS.sh)); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('Non-self stress, shear')
caxis(ca), colormap(jet), cb = colorbar; ylabel(cb, 'log_{10}\tau')

figure
mycline([o1'; o2'], [a1'; a2'], (S.sh - SS.sh)./SS.sh); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('% diff., shear')
caxis([-2 2]), colormap(bluewhitered), cb = colorbar; ylabel(cb, 'frac. diff.')

figure
mycline([o1'; o2'], [a1'; a2'], log10(S.nr)); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('All stress, normal')
ca = caxis; cb = colorbar; ylabel(cb, 'log_{10}\sigma_{n}')

figure
mycline([o1'; o2'], [a1'; a2'], log10(SS.nr)); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('Self stress, normal')
caxis(ca), colormap(jet), cb = colorbar; ylabel(cb, 'log_{10}\sigma_{n}')

figure
mycline([o1'; o2'], [a1'; a2'], log10(OS.nr)); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('Non-self stress, normal')
caxis(ca), colormap(jet), cb = colorbar; ylabel(cb, 'log_{10}\sigma_{n}')

figure
mycline([o1'; o2'], [a1'; a2'], (S.nr - SS.nr)./SS.nr); set(get(gca, 'children'), 'linewidth', 5); axis equal
aa = axis;
line([seg.lon1(:)'; seg.lon2(:)'], [seg.lat1(:)'; seg.lat2(:)'], 'color', 0.75*[1 1 1])
axis(aa);
title('% diff., normal')
caxis([-2 2]), colormap(bluewhitered), cb = colorbar; ylabel(cb, 'frac. diff.')

% Plot slip and stress versus distance

% First order the segments
self = structsubset(seg, idx);
selfo = ordersegs(self);
leng = distance(self.lat1, self.lon1, self.lat2, self.lon2, almanac('earth', 'wgs84'));
cl = cumsum(leng);
figure
ax = plotyy(cl, self.ssRate(selfo), cl, log10(abs(SS.sh(selfo))));
hold(ax(2), 'on')
plot(ax(2), cl, log10(abs(S.sh(selfo))), 'r');
axis(ax, 'tight')

