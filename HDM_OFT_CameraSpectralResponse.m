function out=HDM_OFT_CameraSpectralResponse(OFT_In_IDTTaskData)

OFT_Env=HDM_OFT_InitEnvironment();

HDM_OFT_Utils.OFT_DispTitle('camera spectral response estimation');

l_Pixel2WavelengthLookUp_HigherOrderPolynomBased = HDM_OFT_LineCalibrationPn...
    (OFT_In_IDTTaskData.SpectralResponse_In_LineCalibrationSpectrum, OFT_In_IDTTaskData.SpectralResponse_In_LineCalibrationImage,...
    OFT_In_IDTTaskData.PreLinearisation_Out_LinCurve, OFT_In_IDTTaskData.SpectralResponse_In_LightCalibrationImage);

OFT_CameraResponse = HDM_OFT_LightCalibrationPn...
    (l_Pixel2WavelengthLookUp_HigherOrderPolynomBased,...
    OFT_In_IDTTaskData.SpectralResponse_In_LightCalibrationSpectrum, OFT_In_IDTTaskData.SpectralResponse_In_LightCalibrationImage,...
    OFT_In_IDTTaskData.PreLinearisation_Out_LinCurve, OFT_In_IDTTaskData.Device_In_Sensor, OFT_In_IDTTaskData.Device_In_FocalLength);

out=OFT_CameraResponse;

HDM_OFT_Utils.OFT_DispTitle('camera spectral response estimation succesfully finished');

end