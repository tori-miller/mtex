function oP = newOrientationPlot(CS1,CS2,varargin)
  
% create a new mtexFigure or get a reference to it
[mtexFig,isNew] = newMtexFigure(varargin{:});

% maybe we plot into an existing orientationPlot
if ~isNew && isappdata(mtexFig.gca,'orientationPlot')
  oP = getappdata(mtexFig.gca,'orientationPlot');
  
  if oP.CS1.properGroup.id == CS1.properGroup.id ...
      && oP.CS2.properGroup.id == CS2.properGroup.id
    return, 
  end
end

% basic 3d settings
if isNew
  fcw;
  view(mtexFig.gca,3);
  grid(mtexFig.gca,'on');
  axis(mtexFig.gca,'vis3d','equal','on');
    
  set(mtexFig.parent,'Name',[char(CS1) ' - ' char(CS2)]);
  mtexFig.keepAspectRatio = false;
end

% create a new plot
plotTypes = {'axisAngle','Bunge','Rodrigues','Rodriguez','homochoric','quaternion','conformal'};
plotType = extract_option(varargin,plotTypes);
if isempty_cell(plotType)
  if isa(CS1,'crystalSymmetry') && isa(CS2,'crystalSymmetry')
    plotType = 'axisAngle';
  else
    plotType = 'Bunge';
  end
else
  plotType = plotType{end};
end

switch lower(plotType)
  case 'axisangle'
    oP = axisAnglePlot(mtexFig.gca,CS1,CS2,varargin{:});
  case {'homochoric'}
    oP = homochoricPlot(mtexFig.gca,CS1,CS2,varargin{:});
  case {'rodrigues','rodriguez'}
    oP = RodriguesPlot(mtexFig.gca,CS1,CS2,varargin{:});
  case 'bunge'
    oP = BungePlot(mtexFig.gca,CS1,CS2,varargin{:});
  case 'quaternion'
    oP = quaternionPlot(mtexFig.gca,CS1,CS2,varargin{:});
  case 'conformal'
    oP = conformalPlot(mtexFig.gca,CS1,CS2,varargin{:});
end

end

% compare different representations
% omega = linspace(0,pi).';
% plot(omega./degree,[omega,2*sin(omega./2),2*tan(omega./2),2*(3./4.*(omega-sin(omega))).^(1/3),4*tan(omega./4)]./degree)
% ylim([0,180])
% legend('angle','quaternion','Rodrigues','homochoric','conformal')
 

