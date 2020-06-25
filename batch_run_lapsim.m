%% Construct a batch run - Edit these variables
test_name = 'test_1';

base_car = "BFR 2019.xlsx"; 

cl_var.Name = "Lift Coefficient CL";
cl_var.Type = "Sweep";
cl_var.Values = [ .5, .125, -.5, -1, -2, -3]; %Should be ordered for nice plots

cd_var.Name = "Drag Coefficient CD";
cd_var.Type = "Constant";
cd_var.Values = [-.125]; 

m_var.Name = "Total Mass";
m_var.Type = "Sweep";
m_var.Values = [276, 273]; %Should be ordered for nice plots

vehicle_vars = [cl_var, cd_var, m_var];
tracks = ["OpenTRACK_2019 AutoX_Open_Forward.mat","OpenTRACK_FSAE Skidpad_Closed_Forward.mat"];
sims = {@run_track,@run_accel};

%Plot plot_vars(1) on x for constant plot_vars(2) 
plot_vars = [cl_var,m_var,];


%% Redirect Open*** Files - This is sketch but works
vehicle_xlsx_new_name = '''batch_vehicle.xlsx''';

edit_OPEN_file("OpenVEHICLE.m","batch_vehicle_tester.m","filename =",vehicle_xlsx_new_name,["Plot"])
vehicle_file_new_name = '''OpenVEHICLE Vehicles/OpenVEHICLE_batch_vehicle_Open Wheel.mat''';
edit_OPEN_file("OpenAcceleration.m","batch_accel_tester.m","vehiclefile =",vehicle_file_new_name,["Plots"])
edit_OPEN_file("OpenLAP.m","batch_lap_tester.m","vehiclefile =",vehicle_file_new_name,["Ploting","Report generation"])

track_file_new_name = '''OpenTRACK Tracks/batch_track.mat''';
edit_OPEN_file("batch_lap_tester.m","batch_lap_tester.m","trackfile =",track_file_new_name,[])

%% Run
copyfile(base_car,'batch_vehicle.xlsx');
writecell({"batch_vehicle"},'batch_vehicle.xlsx','Sheet','Info','Range','C2')

base_car_table = readtable(base_car,'Sheet','Info','Range','B1:C52');
for i = 1:length(vehicle_vars)
    var = vehicle_vars(i);
    if var.Type == "Constant"
        base_car_table.Value(base_car_table.Description == var.Name) = var.Values(1);
    end
end
result = run(sims,tracks,vehicle_vars,1,base_car_table);
T = array2table(result.runs);
T.Properties.VariableNames = result.col_names
writetable(T,['batch_run_',test_name,'.xlsx']);
save(['batch_run_',test_name,'.mat'],'T');


primary_index = find(T.Properties.VariableNames == plot_vars(1).Name);
secondary_index = find(T.Properties.VariableNames == plot_vars(2).Name);
for i = length(vehicle_vars)+1:length(result.col_names)
    figure
    hold on
    for j = 1:length(plot_vars(2).Values)
        xs = T(:,primary_index);
        ys = T(:,i);
        mask = T{:,secondary_index}==plot_vars(2).Values(j);
        plot(xs{mask,1},ys{mask,1},'-o','DisplayName',sprintf("%s = %3.2f",[plot_vars(2).Name, plot_vars(2).Values(j)]));
    end
    xlabel(plot_vars(1).Name);
    title(result.col_names{i},'Interpreter','none');
    legend('show');
end


%% Cleanup
delete('batch_vehicle.xlsx')
delete('batch_vehicle_tester.m')
delete('batch_accel_tester.m')
delete('batch_lap_tester.m')

%% Helper Functions

function ret = run(sims,tracks,vehicle_vars,var_ind,base_car_table)
var = vehicle_vars(var_ind);

if var_ind == length(vehicle_vars)
    all_ts = [];
    run_names = [var.Name];
    for j=1:length(var.Values)
        base_car_table.Value(base_car_table.Description == var.Name) = var.Values(j);
        writematrix(base_car_table.Value(:),"batch_vehicle.xlsx",'Sheet',1,'Range','C4:C52');
        save('state.mat');
        batch_vehicle_tester
        close all
        clear all
        load('state.mat');
        delete('state.mat');
        ts = [var.Values(j)];
        for i = 1:length(sims)
            sim = sims{i};
            if isequal(@run_accel,sim)
                new_ret = sim();
                ts(end+1) = new_ret.t;
                if j ==1
                    run_names(end+1) = "Accel";
                end
            else
                for k = 1:length(tracks)
                    new_ret = sim(tracks(k));
                    ts(end+1) = new_ret.t;
                    if j == 1
                        run_names(end+1) = new_ret.name;
                    end
                end
            end
        end
        all_ts(end+1,:) = ts;
    end
    ret.runs = all_ts;
    ret.col_names = run_names;
    return
end

for i = 1:length(var.Values)
    base_car_table.Value(base_car_table.Description == var.Name) = var.Values(i);
    
    new_ret = run(sims,tracks,vehicle_vars,var_ind+1,base_car_table);
    num_new_rows = length(new_ret.runs(:,1));
    new_runs = [var.Values(i)*ones(num_new_rows,1),new_ret.runs];
    if i == 1
       ret.runs = new_runs;
       ret.col_names = [var.Name, new_ret.col_names];
    else
        ret.runs = [ret.runs;new_runs];
    end
  
end

end

function ret  = run_track(track)
track_dir = 'OpenTRACK Tracks/';
copyfile(track_dir+track,'OpenTRACK Tracks/batch_track.mat');

save('state.mat');
batch_lap_tester
close all
load('state.mat');
delete('state.mat');

ret.t = sim.laptime.data;
ret.name = track;
end

function ret  = run_accel()
save('state.mat');
batch_accel_tester
close all
load('state.mat');
delete('state.mat');

ret.t = t_finish;
ret.name = "Accel";
end

%Copies file_path to new_file_path, replacing search_term with new_term,
%and deleting sections
function edit_OPEN_file(file_path,new_file_path,search_term,new_term,sections)
old_file = fileread(file_path);
%Delete sections
for i = 1:length(sections)
    start_ind = strfind(old_file,strcat("%% ",sections(i)));
    end_ind = strfind(old_file(start_ind+5:length(old_file)),"%% ");
    old_file = [old_file(1:start_ind),old_file(start_ind+end_ind(1):length(old_file))];
end

%Search term
start_ind = strfind(old_file,search_term);
line_end_ind = strfind(old_file(start_ind:end),';');
new_file_str = [old_file(1:start_ind-1),search_term,new_term ,old_file(start_ind+line_end_ind(1)-2:end)];

new_file_fid = fopen(new_file_path,'w');
fprintf(new_file_fid,'%s',new_file_str);
fclose(new_file_fid);
end