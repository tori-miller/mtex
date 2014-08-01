classdef grain2d < phaseList & dynProp
  % two dimensional grains

  % properties with as many rows as data
  properties
    poly={}    % cell list of polygons forming the grains
    id=[]      % id of each grain
    meanRotation = rotation % mean rotation of the grains       
  end
    
  % general properties
  properties  
    V = zeros(0,2) % vertices with x,y coordinates    
    boundary = grainBoundary % boundary of the grains
  end
    
  properties (Dependent = true)
    meanOrientation
  end
  
  methods
    function grains = grain2d(ebsd,V,F,D,I_FD,A_Db,A_Do)
                  
      if nargin == 0, return;end
      
      % compute grains as connected components of A_Do
      % I_DG - incidence matrix cells to grains
      I_DG = sparse(1:length(ebsd),double(connectedComponents(A_Do)),1);

      % compute phaseId's     
      grains.phaseId = max(I_DG' * ...
        spdiags(ebsd.phaseId,0,numel(ebsd.phaseId),numel(ebsd.phaseId)),[],2);
      grains.CSList = ebsd.CSList;
      grains.phaseMap = ebsd.phaseMap;
           
      % split face x cell incidence matrix into
      % I_FDext - faces x cells external grain boundaries
      % I_FDint - faces x cells internal grain boundaries
      [I_FDext,I_FDint] = calcBoundary;

      grains.id = 1:numel(grains.phaseId);
      grains.V = V; % vertices
                  
      grains.boundary = grainBoundary(V,F,I_FDext,I_DG,ebsd);
      %grains.A_Db = logical(A_Db);
      %grains.A_Do = logical(A_Do);
      %grains.I_DG = logical(I_DG);

      %
      grains.poly = BoundaryFaceOrder(I_FDext);

      grains.meanRotation = calcMeanRotation;
      
      
      function [I_FDext,I_FDint] = calcBoundary
        % distinguish between interior and exterior grain boundaries      
        
        % cells that have a subgrain boundary, i.e. a boundary with a cell
        % belonging to the same grain
        sub = ((A_Db * I_DG) & I_DG)';                 % grains x cell
        [i,j] = find( diag(any(sub,1))*double(A_Db) ); % all adjacence to those
        sub = any(sub(:,i) & sub(:,j),1);              % pairs in a grain

        % split grain boundaries A_Db into interior and exterior
        A_Db_int = sparse(i(sub),j(sub),1,length(D),length(D));
        A_Db_ext = A_Db - A_Db_int;                    % adjacent over grain boundray
            
        % create incidence graphs
        I_FDbg = diag( sum(I_FD,2)==1 ) * I_FD;
        D_Fbg  = diag(any(I_FDbg,2));
                
        [ix,iy] = find(A_Db_ext);
        D_Fext  = diag(sum(abs(I_FD(:,ix)) & abs(I_FD(:,iy)),2)>0);
        
        I_FDext = (D_Fext| D_Fbg)*I_FD;
        
        [ix,iy] = find(A_Db_int);
        D_Fsub  = diag(sum(abs(I_FD(:,ix)) & abs(I_FD(:,iy)),2)>0);
        I_FDint = D_Fsub*I_FD;
        
        % store edge orientation
        I_FDext = EdgeOrientation(I_FDext);
        I_FDint = EdgeOrientation(I_FDint);
        
      end
      
      
      function I_ED = EdgeOrientation(I_ED)
        % compute the orientation of an edge +1, -1

        x_D = [ebsd.prop.x(:),ebsd.prop.y(:)];
        
        [e,d] = find(I_ED);

        % in complex plane with x_D as point of origin
        e1d = complex(V(F(e,1),1) - x_D(d,1), V(F(e,1),2) - x_D(d,2));
        e2d = complex(V(F(e,2),1) - x_D(d,1), V(F(e,2),2) - x_D(d,2));

        I_ED = sparse(e,d,sign(angle(e1d./e2d)),size(I_ED,1),size(I_ED,2));

      end
      
      function b = BoundaryFaceOrder(I_FD)

        I_FG = I_FD*I_DG;
        [i,d,s] = find(I_FG);

        b = cell(max(d),1);

        onePixelGrain = full(sum(I_DG,1)) == 1;
        [id,jg] = find(I_DG(:,onePixelGrain));
        b(onePixelGrain) = D(id);
        % close single cells

        for k = find(onePixelGrain), b{k} = [b{k} b{k}(1)]; end
        % b(onePixelGrain) = cellfun(@(x) [x x(1)],  b(onePixelGrain),...
        %   'UniformOutput',false);

        cs = [0 cumsum(full(sum(I_FG~=0,1)))];
        for k=find(~onePixelGrain)
          ndx = cs(k)+1:cs(k+1);
  
          E1 = F(i(ndx),:);
          s1 = s(ndx); % flip edge
          E1(s1>0,[2 1]) = E1(s1>0,[1 2]);
  
          b{k} = EulerCycles(E1(:,1),E1(:,2));
  
        end

        for k=find(cellfun('isclass',b(:)','cell'))
          boundary = b{k};
          [~,order] = sort(cellfun('prodofsize', boundary),'descend');
          b{k} = boundary(order);
        end

      end
    
      function meanRotation = calcMeanRotation

        [d,g] = find(I_DG);

        grainSize     = full(sum(I_DG>0,1));   % points per grain
        grainRange    = [0 cumsum(grainSize)];        %
        firstD        = d(grainRange(2:end));
        phaseId       = ebsd.phaseId(firstD);
        q             = quaternion(ebsd.rotations);
        meanRotation  = q(firstD);

        indexedPhases = ~cellfun('isclass',grains.CSList(:),'char');

        for p = grains.indexedPhasesId
          ndx = ebsd.phaseId(d) == p;
          if any(ndx)
            q(d(ndx)) = project2FundamentalRegion(...
              q(d(ndx)),grains.CSList{p},meanRotation(g(ndx)));
          end
  
          % mean may be inaccurate for some grains and should be projected again
          % any(sparse(d(ndx),g(ndx),angle(q(d(ndx)),meanRotation(g(ndx))) > getMaxAngle(ebsd.CS{p})/2))
        end

        doMeanCalc    = find(grainSize(:)>1 & indexedPhases(phaseId));
        cellMean      = cell(size(doMeanCalc));
        for k = 1:numel(doMeanCalc)
          cellMean{k} = d(grainRange(doMeanCalc(k))+1:grainRange(doMeanCalc(k)+1));
        end
        cellMean = cellfun(@mean,partition(q,cellMean),'uniformoutput',false);

        meanRotation(doMeanCalc) = [cellMean{:}];

      end      
    end
    
    function ori = get.meanOrientation(grains)
      
      % ensure single phase
      [grains,cs] = checkSinglePhase(grains);
      
      ori = orientation(grains.meanRotation,cs);
    end
    
  end
  
end

