%%% process the robot sensor and pose data

%% Sonar
% read sonar reading from csv file
addpath('/Users/changliu/Documents/Git/Autonomous_agent_search/multi_agent_search/experiment/data');
clear;
[data_s,~] = readtext('r2_sonar_mobilesim_010416.csv');
sonar_rd = struct();
sonar_rd.time = [data_s{2:end,1}]'; % this time seems to be the epoch time
sonar_rd.stamp = [data_s{2:end,3}]'; % don't understand why stamp is different from time

% convert from epoch time to human-readable time
sonar_rd.time = sonar_rd.time * 1e-9;% # of seconds since 1970.1.1 0h 0m 0s. The original time is in nano-second.
% epoch time -> MATLAB datenum
dnum = datenum(1970,1,1,0,0,sonar_rd.time);
% split time into parts
[Y, M, D, H, MN, S] = datevec(dnum);

sonar_rd.stamp = sonar_rd.stamp * 1e-9;
% epoch time -> MATLAB datenum
dnum2 = datenum(1970,1,1,0,0,sonar_rd.stamp);
% split time into parts
[Y2, M2, D2, H2, MN2, S2] = datevec(dnum2);
sonar_rd.sec_time = H2*3600+MN2*60+S2;% this is the time in seconds taking into account hour, min and second. not starting from 1970 but current day.

sonar_rd.pts = zeros(size(data_s,1)-1,16);
% read readings from 8 front sonars
for ii = 1:8
    sonar_rd.pts(:,2*(ii-1)+1) = [data_s{2:end,3*(ii-1)+5}];
    sonar_rd.pts(:,2*ii) = [data_s{2:end,3*(ii-1)+6}];
end

%% Pose
% read pose reading from csv file
[data_p,~] = readtext('r2_pose_mobilesim_010416.csv');
pose_rd = struct();
pose_rd.time = [data_p{2:end,1}]'; % this time seems to be the epoch time
pose_rd.stamp = [data_p{2:end,3}]'; % don't understand why stamp is different from time

% convert from epoch time to human-readable time
pose_rd.time = pose_rd.time * 1e-9;% # of seconds since 1970.1.1 0h 0m 0s
% epoch time -> MATLAB datenum
dnum3 = datenum(1970,1,1,0,0,pose_rd.time);
% split time into parts
[Y3, M3, D3, H3, MN3, S3] = datevec(dnum3);

pose_rd.stamp = pose_rd.stamp * 1e-9;
% epoch time -> MATLAB datenum
dnum4 = datenum(1970,1,1,0,0,pose_rd.stamp);
% split time into parts
[Y4, M4, D4, H4, MN4, S4] = datevec(dnum4);
pose_rd.sec_time = H4*3600+MN4*60+S4;% this is the time in seconds taking into account hour, min and second. not starting from 1970 but current day.

% position
[~,pos_x_idx] = ismember('field.pose.pose.position.x',data_p(1,:)); % position
[~,pos_y_idx] = ismember('field.pose.pose.position.y',data_p(1,:)); % position
% note: orientation takes quaternion format
[~,ori_x_idx] = ismember('field.pose.pose.orientation.x',data_p(1,:)); % orientation
[~,ori_y_idx] = ismember('field.pose.pose.orientation.y',data_p(1,:)); % orientation
[~,ori_z_idx] = ismember('field.pose.pose.orientation.z',data_p(1,:)); % orientation
[~,ori_w_idx] = ismember('field.pose.pose.orientation.w',data_p(1,:)); % orientation

% convert orientation to axis angle
qx = [data_p{2:end,ori_x_idx}]';
qy = [data_p{2:end,ori_y_idx}]';
qw = [data_p{2:end,ori_w_idx}]';
qz = [data_p{2:end,ori_z_idx}]';
% ori = 2*acos(qw);
% ori_deg = ori/pi*180;
% z = [data_p{2:end,pos_z_idx}]./sqrt(1-qw.*qw);

% convert orientation to Euler angle
% phi = atan2(2*(qw.*qx+qy.*qz),1-2*(qx.^2+qy.^2)); % row
% theta = asin(2*(qw.*qy-qz.*qx)); % pitch
psi = atan2(2*(qw.*qz+qx.*qy),1-2*(qy.^2+qz.^2)); % yaw
ltzero_idx = (psi < 0);
psi(ltzero_idx) = psi(ltzero_idx)+2*pi;
psi_deg = psi/pi*180;

% velocity
[~,vel_x_idx] = ismember('field.twist.twist.linear.x',data_p(1,:)); % linear velocity
[~,vel_y_idx] = ismember('field.twist.twist.linear.y',data_p(1,:)); % linear velocity
[~,vel_z_idx] = ismember('field.twist.twist.angular.z',data_p(1,:)); % angular velocity

% read pose readings
% poses in data_p assumes the initial position of robot as (0,0,0), adding
% the home position to data_p to get state in global coordinate.
init_pos = [2;2;0];
pose_rd.pos = bsxfun(@plus,[[data_p{2:end,pos_x_idx}];[data_p{2:end,pos_y_idx}];psi'],init_pos); % [pos_x;pos_y;orientation]
pose_rd.vel = [[data_p{2:end,vel_x_idx}];[data_p{2:end,vel_y_idx}];[data_p{2:end,vel_z_idx}]]; %[v_x;v_y;v_angular];

%% Compute object distance
% compute measured distance
num = length(pose_rd.time); % number of readings
sonar_ori = [90,50,30,10,-10,-30,-50,-90]/180*pi;
obj_pos = zeros(2*num,8); % there are 8 sonar readings [x1;y1;x2;y2;...;x8;y8]
obj_dist = zeros(num,8); % there are 8 sonar readings [dis1,...,dis8]
obj_ori = zeros(num,8); % orientation relative to robot local cooridnate
for ii = 1:num
%     obj_pos(2*(ii-1)+1:2*ii,:) = bsxfun(@plus, reshape(sonar_rd.pts(ii,:),2,8),pose_rd.pos(1:2,ii));
%     obj_dist(ii,:) = sqrt(sum(reshape(sonar_rd.pts(ii,:),2,8).^2,1));
    tmp_loc_pos = reshape(sonar_rd.pts(ii,:),2,8); % convert the local coordinate into 2*8 format instead of 1*16 format
    obj_pos(2*(ii-1)+1:2*ii,:) = tmp_loc_pos;
    obj_dist(ii,:) = sqrt(sum(tmp_loc_pos.^2,1));
    obj_ori(ii,:) = atan2(tmp_loc_pos(2,:),tmp_loc_pos(1,:));
end

% visualize the detected position
% plot(obj_pos(1:2:2*num-1,5),obj_pos(2:2:2*num,5));
    
% wall coordinates: when a measurement is close in x or y coordinates to
% the ones saved here, it is considered as a measurement of walls
wall_x = [0,20];
wall_y = [0,15];
thrd = 0.3; % threshold for deciding if two values match

% retrieve target measurement
sonar_idx = 4; % retrieve a single sonar first
% 1. remove measurements whose reading distance is greater than 5.1m
dis_thrd = 5.1; % threshold for deciding whether maximum distance is returned
log_idx = (obj_dist(:,sonar_idx) <= dis_thrd); % logical indices for measurements that detect an object
tmp_idx = (1:num)';
tmp_idx(log_idx == 0) = [];

%{
% interleave x and y index
det_idx = [2*(tmp_idx-1)+1,2*tmp_idx]';
det_idx = det_idx(:);
tmp_pos2 = obj_pos(det_idx,sonar_idx);

% 2. remove measurements from walls
tmp_idx2 = [];
for jj = 1:size(tmp_pos2,1)/2
    if (abs(tmp_pos2(2*(jj-1)+1)-wall_x(1)) < thrd) || (abs(tmp_pos2(2*(jj-1)+1)-wall_x(2)) < thrd)...
            || (abs(tmp_pos2(2*jj)-wall_y(1)) < thrd) || (abs(tmp_pos2(2*jj)-wall_y(2)) < thrd)
        continue
    else
        tmp_idx2 = [tmp_idx2;jj];
    end
end
tar_idx = [2*(tmp_idx2-1)+1,2*tmp_idx2]';
tar_idx = tar_idx(:);
tar_pos = tmp_pos2(tar_idx); % retrieve the measurement for target
%}

% positions of object in global coordinate
tmp_glb_pos = zeros(2*length(tmp_idx),1);
tmp_idx2 = [];
for jj = 1:length(tmp_idx)
    % quantities in local coordinate
    tmp_obj_dist = obj_dist(tmp_idx(jj),sonar_idx); % distance between sonar and object
    tmp_loc_ori = obj_ori(tmp_idx(jj),sonar_idx); % local orientation from sonar and object
    
    % orientation of object in global coordinate    
    tmp_glb_ori = pose_rd.pos(3,tmp_idx(jj))+tmp_loc_ori;
    tmp_glb_pos(2*(jj-1)+1:2*jj) = pose_rd.pos(1:2,tmp_idx(jj))+tmp_obj_dist*[cos(tmp_glb_ori);sin(tmp_glb_ori)];
    if (abs(tmp_glb_pos(2*(jj-1)+1)-wall_x(1)) < thrd) || (abs(tmp_glb_pos(2*(jj-1)+1)-wall_x(2)) < thrd)...
            || (abs(tmp_glb_pos(2*jj)-wall_y(1)) < thrd) || (abs(tmp_glb_pos(2*jj)-wall_y(2)) < thrd)
        continue
    else
        tmp_idx2 = [tmp_idx2;jj];
    end
end
tar_idx = [2*(tmp_idx2-1)+1,2*tmp_idx2]';
tar_idx = tar_idx(:);
tar_pos = tmp_glb_pos(tar_idx); % retrieve the measurement for target