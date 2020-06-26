%% Construct a batch run - Edit these variables
test_name = 'test_1';

base_car = "BFR 2019.xlsx"; 

cl_var.Name = "Lift Coefficient CL";
cl_var.Type = "Constant";
cl_var.Values = [0]; %Should be ordered for nice plots

lon_var.Name = "Lateral Friction Sensitivity";
lon_var.Type = "Sweep";
lon_var.Values = [0.00033474,.0001]; 

m_var.Name = "Total Mass";
m_var.Type = "Constant";
m_var.Values = [267]; %Should be ordered for nice plots

vehicle_vars = [lon_var,cl_var];
base_config_index = [2,1,1]; %Index into each vehicle var for the sim to use as reference

%tracks = ["OpenTRACK_2019 AutoX_Open_Forward.mat","OpenTRACK_FSAE Skidpad_Closed_Forward.mat"];

%Plot plot_vars(1) on x for constant plot_vars(2) 
plot_vars = [lon_var,cl_var];

auto_x_weight = .5;
enduro_weight = .7;
skid_weight = .2;
accel_weight = .4;
ref_times = [];

%Order should match for below
sim_weights = [auto_x_weight,enduro_weight,skid_weight,accel_weight];
%sims = {@run_autox,@run_enduro,@run_skid,@run_accel};
sims = {@run_skid};


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
result = run(sims,vehicle_vars,1,base_car_table);
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

function ret = run(sims,vehicle_vars,var_ind,base_car_table)
var = vehicle_vars(var_ind);

if var_ind == length(vehicle_vars)
    all_ts = [];
    run_names = [var.Name];
    for j=1:length(var.Values)
        base_car_table.Value(base_car_table.Description == var.Name) = var.Values(j);
        writematrix(base_car_table.Value(:),"batch_vehicle.xlsx",'Sheet',1,'Range','C4:C52');
        writecell({"RWD"},'batch_vehicle.xlsx','Sheet','Info','Range','C36')
        save('state.mat');
        batch_vehicle_tester
        close all
        clear all
        load('state.mat');
        delete('state.mat');
        ts = [var.Values(j)];
        for i = 1:length(sims)
            sim = sims{i};
            new_ret = sim();
            if(j ==1)
                run_names(end+1) = new_ret.name;
            end
            ts(end+1) = new_ret.t;
%             if isequal(@run_accel,sim)
%                 new_ret = sim();
%                 ts(end+1) = new_ret.t;
%                 if j ==1
%                     run_names(end+1) = "Accel";
%                 end
%             else
%                 for k = 1:length(tracks)
%                     
%                     ts(end+1) = new_ret.t;
%                     if j == 1
%                         run_names(end+1) = new_ret.name;
%                     end
%                 end
%             end
        end
        all_ts(end+1,:) = ts;
    end
    ret.runs = all_ts;
    ret.col_names = run_names;
    return
end

for i = 1:length(var.Values)
    base_car_table.Value(base_car_table.Description == var.Name) = var.Values(i);
    
    new_ret = run(sims,vehicle_vars,var_ind+1,base_car_table);
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

function ret  = run_custom()
track_dir = 'OpenTRACK Tracks/';
track = "";
copyfile(track_dir+track,'OpenTRACK Tracks/batch_track.mat');

save('state.mat');
batch_lap_tester
close all
load('state.mat');
delete('state.mat');

ret.t = sim.laptime.data;
ret.name = track;
end

function ret  = run_autox()
track_dir = 'OpenTRACK Tracks/';
track = "OpenTRACK_2019 AutoX_Open_Forward.mat";
copyfile(track_dir+track,'OpenTRACK Tracks/batch_track.mat');

save('state.mat');
batch_lap_tester
close all
load('state.mat');
delete('state.mat');

a = 1.8826; b = 2.9227;
ret.t = sim.laptime.data;
ret.name = "AutoX";
end

function ret  = run_enduro()
track_dir = 'OpenTRACK Tracks/';
track = "OpenTRACK_2019 Endurance_Closed_Forward.mat";
copyfile(track_dir+track,'OpenTRACK Tracks/batch_track.mat');

save('state.mat');
batch_lap_tester
close all
load('state.mat');
delete('state.mat');

a = .4309; b = 1.3906;
ref_real_time = 1630.377/11;
ref_sim_time = 0;
winning_time = 1267.742/11;
ret.t = sim.laptime.data;
ret.name = "Enduro";
end

function ret  = run_skid()
track_dir = 'OpenTRACK Tracks/';
track = "OpenTRACK_FSAE Skidpad_Closed_Forward.mat";
copyfile(track_dir+track,'OpenTRACK Tracks/batch_track.mat');

save('state.mat');
batch_lap_tester
close all
load('state.mat');
delete('state.mat');

a = 5.3069; b = 5.1148;

ret.t = sim.laptime.data;
ret.name = "Skidpad";
end

function ret  = run_accel()
save('state.mat');
batch_accel_tester
close all
load('state.mat');
delete('state.mat');

a = 1.7759; b = 2.7479;
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