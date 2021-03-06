function evaluateMorpho(seq, fileFormat, alphaValues, morphThresholds, morphFunction, colorIm, colorTransform, shadowRemove, task)
    %% evaluateMorpho
    % Iterate through all sequences and apply a morphological operation
    % specified by morphFunction (which, at the same time, will iterate in
    % the values specified in morphThreshold). The precision recall curve
    % and its AUC will be calculated.
    % Input:
    %   - seq: struct containing all the sequence info
    %   - folderBaseResults: string indicating the folder were the results
    %                        will be saved.
    %   - morphFunction: function that will apply a morphological operation
    %                    to each resulting mask. Parameters of morphFunction
    %                    have to be like (masks, morphThreshold(i))                    
    %   - morphThresholds: thresholds used to iterate through morphFunction.
    %   - task: string indicating the task id that will be used to store
    %     the results.
    
    if ~exist('morphFunction','var')
        morphFunction = @(x)x;
    end
    if ~exist('shadowRemove','var')
        morphFunction = false;
    end
    if ~exist('task','var')
        task = '';
    end
    
    saveIm = false; % We don't want to store any masks for this evaluation
    
    prec1 = zeros(seq.nSequences, length(alphaValues)); 
    rec1= zeros(seq.nSequences, length(alphaValues)); 
    f1score1 = zeros(seq.nSequences, length(alphaValues));
    
    prec2 = zeros(seq.nSequences, length(alphaValues), length(morphThresholds)); 
    rec2= zeros(seq.nSequences, length(alphaValues), length(morphThresholds)); 
    f1score2 = zeros(seq.nSequences, length(alphaValues), length(morphThresholds));
    
    % Initialize verbose stuff
    dispstat('','init');
    dispstat(['Initiating Task ' task],'keepthis');
    dispstat(sprintf('\tProgress: 0%%'));
    totalIterations = seq.nSequences*length(alphaValues)*length(morphThresholds);
    
    % Apply the algorithm to each sequence
    count = 1;
    for i=1:seq.nSequences
        j=1;
        for alpha=alphaValues(:)'
            % Calculate Block 2 results using this alpha
            [masks, maskNames] = oneGaussianBackgroundAdaptive( seq.framesInd{i}, seq.inputFolders{i},...
                    fileFormat, alpha, seq.rhos(i), colorIm , colorTransform, saveIm);           

            % Evaluate the Block 2 results
            [ tpAux , fpAux , fnAux , tnAux , ~ , ~ ] =  ...
                segmentationEvaluation(seq.gtFolders{i}, masks, maskNames);
            tp = sum(tpAux); fp = sum(fpAux); fn = sum(fnAux); tn = sum(tnAux);
            [ precAux , recAux , f1Aux ] = getMetrics( tp , fp , fn , tn );
            prec1(i, j) = precAux; rec1(i, j) = recAux; f1score1(i, j) = f1Aux;

            % Apply the algorithm to all the morphThreshold options
            k = 1;
            for morphTh = morphThresholds
                % Apply the morphology methods specified in morphFunction
                
                [masksMorph, maskNames] = oneGaussianBackgroundAdaptive( seq.framesInd{i}, seq.inputFolders{i},...
                    fileFormat, alpha, seq.rhos(i), colorIm , colorTransform, saveIm, '', @(x) morphFunction(x, morphTh), shadowRemove);   

                % Evaluate the morphoTask1 results
                [ tpAux , fpAux , fnAux , tnAux , ~ , ~ ] =  ...
                    segmentationEvaluation(seq.gtFolders{i}, masksMorph, maskNames);
                tp = sum(tpAux); fp = sum(fpAux); fn = sum(fnAux); tn = sum(tnAux);
                [ precAux , recAux , f1Aux ] = getMetrics( tp , fp , fn , tn );
                prec2(i, j, k) = precAux; rec2(i, j, k) = recAux; f1score2(i, j, k) = f1Aux;

                k = k + 1;
                dispstat(sprintf('\tProgress: %.2f%%', 100*(count/totalIterations)));
                count = count + 1;
            end
            j = j + 1;
        end
    end
    
    % Comparation results
    if ~exist('savedResults','dir')
        mkdir('savedResults');
    end
    save(['savedResults' filesep 'dataTask' task], 'prec1', 'rec1', 'f1score1', 'prec2', 'rec2', 'f1score2', 'alphaValues', 'morphThresholds');
    
end
