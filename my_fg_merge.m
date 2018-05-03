function my_fg_merge()

addpath(genpath('/N/u/hayashis/BigRed2/git/vistasoft'));

fid = fopen('tract_name_list.txt');
tline = fgetl(fid);
load(tline);
fg_classified=fg;

while ischar(tline)
    disp(tline);
    load(tline);
    new_name = strrep(tline,'_',' ');
    fg.name = new_name;
    fg_classified = [fg_classified, fg];
    tline = fgetl(fid);
end

fgWrite(fg_classified(2:end), 'output', 'mat');
fclose(fid);

exit;
end
