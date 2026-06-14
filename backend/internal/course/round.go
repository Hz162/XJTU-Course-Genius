package course

import (
	"encoding/json"
	"fmt"
	"time"

	"xjtu-course-genius/internal/session"

	"github.com/go-resty/resty/v2"
)

func GetBatches(client *resty.Client) ([]BatchInfo, error) {
	s := session.Get()
	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/%s.do?timestamp=%d",
		baseURL, s.StudentCode, time.Now().UnixMilli())

	resp, err := client.R().Get(url)
	if err != nil {
		return nil, fmt.Errorf("获取轮次失败: %w", err)
	}
	var j struct {
		Data struct {
			ElectiveBatchList []struct {
				Code      string `json:"code"`
				Name      string `json:"name"`
				CanSelect string `json:"canSelect"`
			} `json:"electiveBatchList"`
		} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body(), &j); err != nil {
		return nil, fmt.Errorf("解析轮次失败: %w", err)
	}
	var batches []BatchInfo
	for _, b := range j.Data.ElectiveBatchList {
		batches = append(batches, BatchInfo{
			Code:      b.Code,
			Name:      b.Name,
			CanSelect: b.CanSelect,
		})
	}
	return batches, nil
}

func EnterRound(client *resty.Client, batchCode string) error {
	session.SetBatchCode(batchCode)
	s := session.Get()

	url := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/student/xkxf.do", baseURL)
	resp, err := client.R().
		SetFormData(map[string]string{
			"xh":     s.StudentCode,
			"xklcdm": batchCode,
			"xklclx": "01",
		}).
		Post(url)
	if err != nil {
		return fmt.Errorf("进入轮次失败: %w", err)
	}

	var j struct {
		Data struct {
			Campus string `json:"campus"`
		} `json:"data"`
	}
	json.Unmarshal(resp.Body(), &j)
	session.SetCampus(j.Data.Campus)

	dictURL := fmt.Sprintf("%s/xsxkapp/sys/xsxkapp/publicinfo/dictionary.do?timestamp=%d",
		baseURL, time.Now().UnixMilli())
	dictResp, err := client.R().Get(dictURL)
	if err == nil {
		var dj struct {
			Data struct {
				DictionaryList struct {
					XQ []struct {
						Code string `json:"code"`
						Name string `json:"name"`
					} `json:"XQ"`
				} `json:"dictionaryList"`
			} `json:"data"`
		}
		if json.Unmarshal(dictResp.Body(), &dj) == nil {
			var list []session.CampusInfo
			for _, x := range dj.Data.DictionaryList.XQ {
				list = append(list, session.CampusInfo{Code: x.Code, Name: x.Name})
			}
			session.SetCampusList(list)
		}
	}
	return nil
}
